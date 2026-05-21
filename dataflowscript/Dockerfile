FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:latest AS launcher

FROM python:3.12.13-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        default-jre-headless \
        gcc \
        g++ \
        build-essential \
        libffi-dev \
        libc6-dev \
        cargo \
        git && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /template /opt/google/dataflow

COPY --from=launcher \
    /opt/google/dataflow/python_template_launcher \
    /opt/google/dataflow/python_template_launcher

RUN chmod +x /opt/google/dataflow/python_template_launcher

COPY requirements.txt /template/requirements.txt
COPY oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py

RUN pip install --no-cache-dir --root-user-action=ignore \
        --upgrade pip setuptools wheel

RUN pip install --no-cache-dir \
        --root-user-action=ignore \
        -r /template/requirements.txt

ENV FLEX_TEMPLATE_PYTHON_PY_FILE=/template/oden_pubsub_to_gcs.py
ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE=/template/requirements.txt

WORKDIR /template

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]