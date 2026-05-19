FROM gcr.io/dataflow-templates-base/python312-template-launcher-base:latest
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        default-jre-headless \
        curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 \
            --gid appgroup \
            --no-create-home \
            --shell /sbin/nologin \
            appuser
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"
#ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE="/template/requirements.txt"
 
COPY --chown=appuser:appgroup requirements.txt      /template/requirements.txt
COPY --chown=appuser:appgroup oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py
 
RUN chmod 550 /template && \
    chmod 440 /template/requirements.txt \
              /template/oden_pubsub_to_gcs.py
 
# ── Install dependencies ──────────────────────────────────────────────────────
RUN pip install --no-cache-dir \
    --root-user-action=ignore \
    -r /template/requirements.txt && \
    pip cache purge
 
HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=15s \
            --retries=3 \
    CMD test -x /opt/google/dataflow/python_template_launcher || exit 1
 
USER appuser
 
WORKDIR /template
 
ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]