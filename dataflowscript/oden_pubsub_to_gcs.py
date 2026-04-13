"""
Dataflow Pipeline: Pub/Sub -> GCS (Parsed Bronze Landing - Parquet)

Based on Google's official sample:
  https://cloud.google.com/pubsub/docs/samples/pubsub-to-gcs

Architecture:
  ReadFromPubSub -> ParseAndFanOut -> FixedWindows -> WithKeys (shard) -> GroupByKey -> WriteToGCS

- Reads Pub/Sub messages, parses JSON, fans out body[] arrays
- Fixed windows (default 1 hour) to batch writes
- GroupByKey enforces 1 file per window per shard
- Parquet output with gzip compression
- num_shards controls parallelism (default 1 = single file per window)

Output structure:
  gs://<output_path>/YYYY/MM/DD/HH/oden-HH:MM-HH:MM-<shard>.parquet

Parquet schema:
  tagname      STRING
  epochtime    INT64   (milliseconds since epoch, raw from Oden)
  tagvalue     FLOAT64 (float to handle decimals)
  quality      INT64
  sq           INT64   (extracted from nested attributes)
  message_id   INT64   (top-level messageId from Oden)
  status_code  INT64   (top-level statusCode from Oden)

Requires: apache-beam[gcp], pyarrow
"""

import argparse
import json
import logging
import random

from apache_beam import (
    DoFn,
    GroupByKey,
    io,
    Map,
    ParDo,
    Pipeline,
    PTransform,
    WindowInto,
    WithKeys,
)
from apache_beam.io.gcp.pubsub import ReadFromPubSub
from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions
from apache_beam.transforms.window import FixedWindows


class ParseAndFanOut(DoFn):
    """Parse JSON, fan out body[] array, yield flat dicts.

    Single message:  {"tagname":"x","epochtime":123,...,"attributes":{"sq":0}}
    Batched message: {"body":[{...},{...}]}

    Extracts sq from nested attributes and flattens into top-level field.
    """

    def process(self, element):
        try:
            payload = json.loads(element)
        except (json.JSONDecodeError, TypeError):
            logging.warning(f"Skipping invalid JSON: {element[:200]}")
            return

        # Fan out: if body[] exists, explode; otherwise treat as single record
        if "body" in payload and isinstance(payload["body"], list):
            items = payload["body"]
        else:
            items = [payload]

        # Top-level fields carried into every row
        message_id = payload.get("messageId")
        status_code = payload.get("statusCode")

        for item in items:
            sq = None
            if "attributes" in item and isinstance(item["attributes"], dict):
                sq = item["attributes"].get("sq")

            yield {
                "tagname": item.get("tagname"),
                "epochtime": item.get("epochtime"),
                "tagvalue": item.get("tagvalue"),
                "quality": item.get("quality"),
                "sq": sq,
                "message_id": message_id,
                "status_code": status_code,
            }


class GroupMessagesByFixedWindows(PTransform):
    """A composite transform that groups Pub/Sub messages based on publish time.

    Based on Google's official sample:
    https://cloud.google.com/pubsub/docs/samples/pubsub-to-gcs

    WindowInto assigns each message to a window based on its timestamp.
    WithKeys assigns a random shard key (0 to num_shards-1).
    GroupByKey collects all messages with the same key in the same window.

    This ensures:
    - Messages are batched by window
    - num_shards controls how many files per window
    - num_shards=1 means exactly 1 file per window
    """

    def __init__(self, window_size, num_shards=1):
        self.window_size = int(window_size)
        self.num_shards = num_shards

    def expand(self, pcoll):
        return (
            pcoll
            | "Window into fixed intervals"
            >> WindowInto(FixedWindows(self.window_size))
            | "Add shard key"
            >> WithKeys(lambda _: random.randint(0, self.num_shards - 1))
            | "Group by key" >> GroupByKey()
        )


class WriteToGCS(DoFn):
    """Write each group of parsed records as a single gzip-compressed Parquet file.

    Uses PyArrow to build a typed table and write Parquet with gzip compression.
    Uses GcsIO().open() to upload to GCS.
    """

    def __init__(self, output_path):
        self.output_path = output_path.rstrip("/")

    def process(self, key_value, window=DoFn.WindowParam):
        import pyarrow as pa
        import pyarrow.parquet as pq
        import io as _io
        from datetime import datetime, timezone

        shard_id, batch = key_value

        window_start = datetime.fromtimestamp(
            window.start.micros / 1e6, tz=timezone.utc
        )
        window_end = datetime.fromtimestamp(
            window.end.micros / 1e6, tz=timezone.utc
        )

        partition = window_start.strftime("%Y/%m/%d/%H")
        ts_format = "%H:%M"
        window_start_str = window_start.strftime(ts_format)
        window_end_str = window_end.strftime(ts_format)
        filename = (
            f"{self.output_path}/{partition}/"
            f"oden-{window_start_str}-{window_end_str}-{shard_id}.parquet"
        )

        records = list(batch)

        # Build column arrays
        tagnames = []
        epochtimes = []
        tagvalues = []
        qualities = []
        sqs = []
        message_ids = []
        status_codes = []
        valid_count = 0
        invalid_count = 0

        for record in records:
            if not isinstance(record, dict):
                invalid_count += 1
                continue

            tagnames.append(record.get("tagname"))
            epochtimes.append(record.get("epochtime"))

            tv = record.get("tagvalue")
            tagvalues.append(float(tv) if tv is not None else None)

            qualities.append(record.get("quality"))
            sqs.append(record.get("sq"))
            message_ids.append(record.get("message_id"))
            status_codes.append(record.get("status_code"))
            valid_count += 1

        if valid_count == 0:
            logging.warning(f"No valid records for {filename}")
            return

        # Build PyArrow table and write Parquet with gzip compression
        table = pa.table({
            "tagname": pa.array(tagnames, type=pa.string()),
            "epochtime": pa.array(epochtimes, type=pa.int64()),
            "tagvalue": pa.array(tagvalues, type=pa.float64()),
            "quality": pa.array(qualities, type=pa.int64()),
            "sq": pa.array(sqs, type=pa.int64()),
            "message_id": pa.array(message_ids, type=pa.int64()),
            "status_code": pa.array(status_codes, type=pa.int64()),
        })

        buf = _io.BytesIO()
        pq.write_table(table, buf, compression="gzip")
        parquet_bytes = buf.getvalue()

        with io.gcsio.GcsIO().open(
            filename=filename, mode="w", mime_type="application/octet-stream"
        ) as f:
            f.write(parquet_bytes)

        logging.info(
            f"Wrote {valid_count} records ({len(parquet_bytes)} bytes) to {filename}"
            f" (skipped {invalid_count} invalid)"
        )


def run(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input_subscription",
        required=True,
        help="Pub/Sub subscription path: projects/<PROJECT>/subscriptions/<SUB>",
    )
    parser.add_argument(
        "--output_path",
        required=True,
        help="GCS output path, e.g. gs://bucket/bronze/oden",
    )
    parser.add_argument(
        "--window_size",
        type=int,
        default=3600,
        help="Window size in seconds (default: 3600 = 1 hour)",
    )
    parser.add_argument(
        "--num_shards",
        type=int,
        default=1,
        help="Number of output shards per window (default: 1 = single file)",
    )

    known_args, pipeline_args = parser.parse_known_args(argv)

    options = PipelineOptions(
        pipeline_args, streaming=True, save_main_session=True
    )

    with Pipeline(options=options) as p:
        (
            p
            | "Read from Pub/Sub"
            >> ReadFromPubSub(subscription=known_args.input_subscription)
            # Decode bytes to string
            | "Decode" >> Map(lambda msg: msg.decode("utf-8"))
            # Parse JSON + fan out body[] array into flat records
            | "Parse and Fan Out" >> ParDo(ParseAndFanOut())
            # Window + Shard + GroupByKey (batches per window)
            | "Window and Group"
            >> GroupMessagesByFixedWindows(
                known_args.window_size, known_args.num_shards
            )
            # Write each group as ONE gzip Parquet file to GCS
            | "Write to GCS" >> ParDo(WriteToGCS(known_args.output_path))
        )


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run()
