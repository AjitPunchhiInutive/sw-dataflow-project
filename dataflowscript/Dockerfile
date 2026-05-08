# ── Stage 1: Extract launcher binary only ────────────────────────────────────
# Use the Dataflow base image solely to get the launcher binary.
# Nothing else from this stage reaches the final image.
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:20260122-rc00 AS launcher

# ── Stage 2: Clean runtime ────────────────────────────────────────────────────
# apache/beam_python3.11_sdk is actively maintained by the Apache Beam team,
# regularly patched, and purpose-built for Dataflow workloads.
# Significantly fewer CVEs than the full Dataflow base image.
FROM apache/beam_python3.11_sdk:2.62.0

# ── Copy ONLY the launcher binary from the Dataflow base ─────────────────────
# This is the only file needed from gcr.io/dataflow-templates-base
COPY --from=launcher /opt/google/dataflow/python_template_launcher \
                     /opt/google/dataflow/python_template_launcher

# ── Install Java (required by Dataflow template launcher) ─────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        default-jre-headless \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ── Create non-root user and group ───────────────────────────────────────────
RUN groupadd --gid 1001 appgroup && \
    useradd  --uid 1001 \
             --gid appgroup \
             --no-create-home \
             --shell /sbin/nologin \
             appuser

# ── Set template env vars ─────────────────────────────────────────────────────
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"

# ── Copy files with restricted ownership ─────────────────────────────────────
COPY --chown=appuser:appgroup requirements.txt       /template/requirements.txt
COPY --chown=appuser:appgroup oden_pubsub_to_gcs.py  /template/oden_pubsub_to_gcs.py

# ── Lock down template directory permissions ──────────────────────────────────
RUN chmod 550 /template && \
    chmod 440 /template/requirements.txt \
              /template/oden_pubsub_to_gcs.py

# ── Install Python dependencies ───────────────────────────────────────────────
# apache-beam and pyarrow prebuilt wheels are available on this Debian/glibc image
RUN pip install --no-cache-dir \
        --root-user-action=ignore \
        -r /template/requirements.txt && \
    pip cache purge

# ── Health check ──────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=15s \
            --retries=3 \
    CMD test -x /opt/google/dataflow/python_template_launcher || exit 1

# ── Drop to non-root user ─────────────────────────────────────────────────────
USER appuser

WORKDIR /template

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]