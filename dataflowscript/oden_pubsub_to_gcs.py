#!/usr/bin/env python3
"""
Pub/Sub -> Dataflow (Apache Beam, Python) -> BigQuery (Storage Write API) + GCS (Parquet)

Behavior:
- Reads Pub/Sub messages (bytes)
- Supports:
  1) Single JSON object
  2) Multiple JSON objects concatenated in one Pub/Sub message: { ... }\n{ ... }\n{ ... }
- Each JSON object can contain body[] OR be a single record
- Fans out body[] into 1 output row per tag record
- Writes:
  A) OK rows -> BigQuery historian (WRITE_APPEND) using STORAGE_WRITE_API
  B) Error rows -> BigQuery historian_error (WRITE_APPEND) using STORAGE_WRITE_API
  C) OK rows -> GCS Parquet (gzip) in fixed windows

Important:
- For STORAGE_WRITE_API in Beam Python, TIMESTAMP fields must be Beam Timestamp objects.
- For GCS Parquet output, Beam Timestamp values are converted to ISO strings at write time.
"""

import argparse
import json
import logging
import random
import time
from datetime import datetime, timezone
from typing import Any, Optional

import apache_beam as beam
from apache_beam import DoFn, GroupByKey, PTransform, WindowInto, WithKeys
from apache_beam.io.gcp.pubsub import ReadFromPubSub
from apache_beam.options.pipeline_options import (
    PipelineOptions,
    StandardOptions,
    SetupOptions,
)
from apache_beam.transforms.window import FixedWindows
from apache_beam.utils.timestamp import Timestamp


# -------------------------
# Helpers
# -------------------------

def _safe_int(v: Any) -> Optional[int]:
    if v is None:
        return None
    try:
        return int(float(v))
    except Exception:
        return None


def _safe_float(v: Any) -> Optional[float]:
    if v is None:
        return None
    try:
        return float(v)
    except Exception:
        return None


def _safe_string(v: Any) -> Optional[str]:
    if v is None:
        return None
    if isinstance(v, (dict, list)):
        try:
            return json.dumps(v, ensure_ascii=False)
        except Exception:
            return str(v)
    return str(v)


def _normalize_smart_quotes(s: str) -> str:
    return (
        s.replace("\u201c", '"')
         .replace("\u201d", '"')
         .replace("\u2018", "'")
         .replace("\u2019", "'")
    )


def _now_beam_timestamp() -> Timestamp:
    return Timestamp(micros=int(time.time() * 1_000_000))


def _safe_beam_timestamp_from_epoch_millis(ms: Any) -> Optional[Timestamp]:
    if ms is None:
        return None
    try:
        ms_f = float(ms)
        total_micros = int(ms_f * 1000.0)
        return Timestamp(micros=total_micros)
    except Exception:
        return None


def _beam_ts_to_iso_str(v: Any) -> Optional[str]:
    if v is None:
        return None
    try:
        if isinstance(v, Timestamp):
            return v.to_utc_datetime().replace(tzinfo=timezone.utc).isoformat()
        if isinstance(v, datetime):
            return v.astimezone(timezone.utc).isoformat()
        return str(v)
    except Exception:
        return str(v)


# -------------------------
# Parse + Flatten
# -------------------------

class ParseAndFlatten(beam.DoFn):
    ERROR_TAG = "errors"

    def process(self, element, timestamp=beam.DoFn.TimestampParam):
        raw_payload = element.decode("utf-8", errors="replace")
        raw_payload_norm = _normalize_smart_quotes(raw_payload)

        publish_time = timestamp
        ingestion_time = _now_beam_timestamp()

        def emit_error(err_msg: str, snippet: Optional[str] = None):
            msg = err_msg if not snippet else f"{err_msg} | snippet={snippet}"
            yield beam.pvalue.TaggedOutput(
                self.ERROR_TAG,
                {
                    "publish_time": publish_time,
                    "ingestion_time": ingestion_time,
                    "raw_payload": raw_payload,
                    "error_message": msg,
                },
            )

        decoder = json.JSONDecoder()
        pos = 0
        length = len(raw_payload_norm)

        while pos < length:
            while pos < length and raw_payload_norm[pos].isspace():
                pos += 1
            if pos >= length:
                break

            try:
                msg, idx = decoder.raw_decode(raw_payload_norm, pos)
                pos = idx
            except Exception:
                snippet = raw_payload_norm[pos:pos + 200].replace("\n", "\\n")
                yield from emit_error("Invalid JSON payload", snippet=snippet)
                break

            if not isinstance(msg, dict):
                yield from emit_error(
                    f"Top-level JSON is not an object (got {type(msg).__name__})"
                )
                continue

            messageid = _safe_int(msg.get("messageId") or msg.get("messageid"))
            status = _safe_int(
                msg.get("statusCode") or msg.get("statuscode") or msg.get("status")
            )

            body = msg.get("body", [])
            if body is None:
                body = []
            if isinstance(body, dict):
                body = [body]

            if "body" not in msg:
                body = [msg]

            if not isinstance(body, list):
                yield from emit_error(f"Invalid 'body' type (got {type(body).__name__})")
                continue

            for item in body:
                if not isinstance(item, dict):
                    yield from emit_error("Invalid body element (not an object)")
                    continue

                try:
                    tagname = _safe_string(item.get("tagname"))
                    quality = _safe_int(item.get("quality"))
                    tagvalue_str = _safe_string(item.get("tagvalue"))

                    attrs = item.get("attributes") or {}
                    if not isinstance(attrs, dict):
                        attrs = {}
                    sq_str = _safe_string(attrs.get("sq"))

                    epo_ms = item.get("epochtime")
                    epo_ms_int = _safe_int(epo_ms)
                    epo_ts = _safe_beam_timestamp_from_epoch_millis(epo_ms)

                    yield {
                        # ---- BigQuery fields ----
                        "messageid": messageid,
                        "status": status,
                        "tagname": tagname,
                        "epochtime": epo_ts,
                        "tagvalue": tagvalue_str,
                        "quality": quality,
                        "sq": sq_str,
                        "publish_time": publish_time,
                        "ingestion_time": ingestion_time,

                        # ---- Extra fields for GCS parquet only ----
                        "_epochtime_ms": epo_ms_int,
                        "_tagvalue_float": _safe_float(item.get("tagvalue")),
                        "_sq_int": _safe_int(attrs.get("sq")),
                        "_message_id": messageid,
                        "_status_code": status,
                    }

                except Exception:
                    yield from emit_error("Failed to transform one tag record")


# -------------------------
# GCS batching
# -------------------------

class GroupByFixedWindows(PTransform):
    def __init__(self, window_size_sec: int, num_shards: int = 1):
        self.window_size_sec = int(window_size_sec)
        self.num_shards = int(num_shards)

    def expand(self, pcoll):
        return (
            pcoll
            | "GCS_WindowIntoFixed" >> WindowInto(FixedWindows(self.window_size_sec))
            | "GCS_AddShardKey" >> WithKeys(
                lambda _: random.randint(0, self.num_shards - 1)
            )
            | "GCS_GroupByKey" >> GroupByKey()
        )


class WriteParquetToGCS(DoFn):
    def __init__(self, output_path: str):
        self.output_path = output_path.rstrip("/")

    def process(self, key_value, window=DoFn.WindowParam):
        import io as _io
        import pyarrow as pa
        import pyarrow.parquet as pq
        from apache_beam.io import gcsio

        shard_id, batch_iter = key_value
        records = list(batch_iter)

        window_start = datetime.fromtimestamp(window.start.micros / 1e6, tz=timezone.utc)
        window_end = datetime.fromtimestamp(window.end.micros / 1e6, tz=timezone.utc)

        partition = window_start.strftime("%Y/%m/%d/%H")
        ts_format = "%H:%M"
        filename = (
            f"{self.output_path}/{partition}/"
            f"historian-{window_start.strftime(ts_format)}-"
            f"{window_end.strftime(ts_format)}-{shard_id}.parquet"
        )

        tagnames = []
        epochtimes_ms = []
        tagvalues_f = []
        qualities = []
        sqs = []
        message_ids = []
        status_codes = []
        publish_times = []
        ingestion_times = []

        valid_count = 0
        for r in records:
            if not isinstance(r, dict):
                continue

            tagnames.append(_safe_string(r.get("tagname")))
            epochtimes_ms.append(_safe_int(r.get("_epochtime_ms")))
            tagvalues_f.append(_safe_float(r.get("_tagvalue_float")))
            qualities.append(_safe_int(r.get("quality")))
            sqs.append(_safe_int(r.get("_sq_int")))
            message_ids.append(_safe_int(r.get("_message_id")))
            status_codes.append(_safe_int(r.get("_status_code")))
            publish_times.append(_beam_ts_to_iso_str(r.get("publish_time")))
            ingestion_times.append(_beam_ts_to_iso_str(r.get("ingestion_time")))

            valid_count += 1

        if valid_count == 0:
            logging.warning(f"No valid records for {filename}")
            return

        table = pa.table(
            {
                "tagname": pa.array(tagnames, type=pa.string()),
                "epochtime_ms": pa.array(epochtimes_ms, type=pa.int64()),
                "tagvalue": pa.array(tagvalues_f, type=pa.float64()),
                "quality": pa.array(qualities, type=pa.int64()),
                "sq": pa.array(sqs, type=pa.int64()),
                "message_id": pa.array(message_ids, type=pa.int64()),
                "status_code": pa.array(status_codes, type=pa.int64()),
                "publish_time": pa.array(publish_times, type=pa.string()),
                "ingestion_time": pa.array(ingestion_times, type=pa.string()),
            }
        )

        buf = _io.BytesIO()
        pq.write_table(table, buf, compression="gzip")
        parquet_bytes = buf.getvalue()

        with gcsio.GcsIO().open(
            filename=filename,
            mode="w",
            mime_type="application/octet-stream",
        ) as f:
            f.write(parquet_bytes)

        logging.info(f"Wrote {valid_count} records ({len(parquet_bytes)} bytes) to {filename}")


# -------------------------
# Main
# -------------------------

def run(argv=None):
    parser = argparse.ArgumentParser()

    parser.add_argument("--project", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--subscription", required=True)
    parser.add_argument("--temp_location", required=True)
    parser.add_argument("--staging_location", required=True)
    parser.add_argument("--service_account_email", required=True)
    parser.add_argument("--job_name", required=False)

    parser.add_argument("--bq_table_ok", required=True)
    parser.add_argument("--bq_table_err", required=True)

    parser.add_argument("--gcs_output_path", required=True)
    parser.add_argument("--gcs_window_size", type=int, default=3600)
    parser.add_argument("--gcs_num_shards", type=int, default=1)

    parser.add_argument("--requirements_file", required=False, default=None)

    args, pipeline_args = parser.parse_known_args(argv)

    if args.job_name:
        pipeline_args = pipeline_args + [f"--job_name={args.job_name}"]
    if args.requirements_file:
        pipeline_args = pipeline_args + [f"--requirements_file={args.requirements_file}"]

    pipeline_options = PipelineOptions(
        pipeline_args,
        project=args.project,
        region=args.region,
        temp_location=args.temp_location,
        staging_location=args.staging_location,
        service_account_email=args.service_account_email,
        save_main_session=True,
    )

    pipeline_options.view_as(StandardOptions).streaming = True
    pipeline_options.view_as(SetupOptions).save_main_session = True

    ok_schema = (
        "messageid:INT64,status:INT64,tagname:STRING,epochtime:TIMESTAMP,"
        "tagvalue:STRING,quality:INT64,sq:STRING,publish_time:TIMESTAMP,ingestion_time:TIMESTAMP"
    )
    err_schema = (
        "publish_time:TIMESTAMP,ingestion_time:TIMESTAMP,raw_payload:STRING,error_message:STRING"
    )

    bq_fields = [
        "messageid",
        "status",
        "tagname",
        "epochtime",
        "tagvalue",
        "quality",
        "sq",
        "publish_time",
        "ingestion_time",
    ]

    with beam.Pipeline(options=pipeline_options) as p:
        messages = p | "ReadFromPubSub" >> ReadFromPubSub(
            subscription=args.subscription
        )

        parsed = (
            messages
            | "ParseAndFlatten" >> beam.ParDo(ParseAndFlatten()).with_outputs(
                ParseAndFlatten.ERROR_TAG,
                main="ok",
            )
        )

        ok_rows = parsed.ok
        err_rows = parsed[ParseAndFlatten.ERROR_TAG]

        bq_ok_rows = ok_rows | "BQ_SelectSchemaFields" >> beam.Map(
            lambda r: {k: r.get(k) for k in bq_fields}
        )

        bq_ok_rows | "BQ_WriteOK" >> beam.io.WriteToBigQuery(
            table=args.bq_table_ok,
            schema=ok_schema,
            write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
            create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
            method=beam.io.WriteToBigQuery.Method.STORAGE_WRITE_API,
            triggering_frequency=60,
        )

        err_rows | "BQ_WriteERR" >> beam.io.WriteToBigQuery(
            table=args.bq_table_err,
            schema=err_schema,
            write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
            create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
            method=beam.io.WriteToBigQuery.Method.STORAGE_WRITE_API,
            triggering_frequency=60,
        )

        (
            ok_rows
            | "GCS_WindowShardGroup" >> GroupByFixedWindows(
                args.gcs_window_size,
                args.gcs_num_shards,
            )
            | "GCS_WriteParquet" >> beam.ParDo(
                WriteParquetToGCS(args.gcs_output_path)
            )
        )


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run()
