FROM apache/beam_python3.11_sdk:2.62.0

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /template/requirements.txt
RUN pip install --no-cache-dir \
    --root-user-action=ignore \
    -r /template/requirements.txt

COPY oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py

ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"

ENTRYPOINT ["python", "/template/oden_pubsub_to_gcs.py"]