FROM python:3.11-alpine

# ── Install Java + curl ───────────────────────────────────────────────────────
# Alpine uses apk — NOT apt-get
# openjdk17-jre-headless : lightweight JRE for Dataflow template launcher
# curl                   : used by Dataflow health/metadata endpoints
RUN apk add --no-cache \
        openjdk17-jre-headless \
        curl \
        ca-certificates

# ── Create non-root user and group ───────────────────────────────────────────
# Alpine uses addgroup/adduser — NOT groupadd/useradd
RUN addgroup --gid 1001 appgroup && \
    adduser  --uid 1001 \
             --ingroup appgroup \
             --no-create-home \
             --shell /sbin/nologin \
             --disabled-password \
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