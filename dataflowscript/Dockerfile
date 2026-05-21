FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:latest AS launcher
FROM python:3.11.15-alpine3.22
RUN apk add --no-cache openjdk17-jre-headless
RUN addgroup -g 1001 appgroup && \
    adduser -D -u 1001 -G appgroup appuser
COPY --from=launcher \
    /opt/google/dataflow/python_template_launcher \
    /opt/google/dataflow/python_template_launcher
COPY requirements.txt oden_pubsub_to_gcs.py /template/
RUN pip install --no-cache-dir \
    --root-user-action=ignore \
    -r /template/requirements.txt
ENV FLEX_TEMPLATE_PYTHON_PY_FILE=/template/oden_pubsub_to_gcs.py \
    FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE=/template/requirements.txt
USER appuser
WORKDIR /template
ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]