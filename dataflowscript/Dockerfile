# Use the original pinned tag from your working Dockerfile.
# This is the Google-provided base that ships with the Flex Template launcher
# binary at /opt/google/dataflow/python_template_launcher
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:20260122-rc00

# ── Install Java + curl ───────────────────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        default-jre-headless \
        curl \
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
#ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE="/template/requirements.txt"

# ── Copy files with restricted ownership ─────────────────────────────────────
COPY --chown=appuser:appgroup requirements.txt       /template/requirements.txt
COPY --chown=appuser:appgroup oden_pubsub_to_gcs.py  /template/oden_pubsub_to_gcs.py

# ── Lock down template directory permissions ──────────────────────────────────
RUN chmod 550 /template && \
    chmod 440 /template/requirements.txt \
              /template/oden_pubsub_to_gcs.py

# ── Install Python dependencies ───────────────────────────────────────────────
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