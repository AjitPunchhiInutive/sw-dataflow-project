FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:latest

# ── Install Java ──────────────────────────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── Set template env vars ─────────────────────────────────────────────────────
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"
ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE="/template/requirements.txt"

# ── Copy files ────────────────────────────────────────────────────────────────
COPY requirements.txt      /template/requirements.txt
COPY oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py

# ── Install dependencies ──────────────────────────────────────────────────────
RUN pip install --no-cache-dir \
    --root-user-action=ignore \
    -r /template/requirements.txt

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]