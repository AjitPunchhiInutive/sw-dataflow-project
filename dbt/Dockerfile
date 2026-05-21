FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:latest AS launcher

FROM python:3.11-slim-bookworm

COPY --from=launcher /opt/google/dataflow/python_template_launcher \
                     /opt/google/dataflow/python_template_launcher

RUN apt-get update -qq && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends default-jre-headless gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup \
            --no-create-home --shell /usr/sbin/nologin appuser

ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"
ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE="/template/requirements.txt"

COPY requirements.txt      /template/requirements.txt
COPY oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py

RUN pip install --no-cache-dir --root-user-action=ignore \
        --upgrade "pip>=26.1" setuptools wheel && \
    pip install --no-cache-dir --root-user-action=ignore \
        -r /template/requirements.txt

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR /template
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]