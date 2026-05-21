# ── Stage 1: extract ONLY the launcher from the heavy base image ──────
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:latest AS launcher

# ── Stage 2: stable runtime for Apache Beam/Dataflow ─────────────────
FROM python:3.12.13-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        gcc \
        g++ \
        build-essential \
        python3-dev \
        libffi-dev \
        libc6-dev \
        cargo \
        git && \
    rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /template /opt/google/dataflow

# Copy Dataflow launcher
COPY --from=launcher \
    /opt/google/dataflow/python_template_launcher \
    /opt/google/dataflow/python_template_launcher

# Ensure launcher executable
RUN chmod +x /opt/google/dataflow/python_template_launcher

# Copy files
COPY requirements.txt /template/requirements.txt
COPY oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py

# Upgrade pip tooling
RUN pip install --upgrade "pip>=26.1" setuptools wheel

# Install Python dependencies
RUN pip install --no-cache-dir \
        --root-user-action=ignore \
        -r /template/requirements.txt

# Environment variables
ENV FLEX_TEMPLATE_PYTHON_PY_FILE=/template/oden_pubsub_to_gcs.py
ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE=/template/requirements.txt

WORKDIR /template

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]