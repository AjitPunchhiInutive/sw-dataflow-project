# ── Stage 1: extract ONLY the launcher from the heavy base image ──────
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:latest AS launcher
# ── Stage 2: minimal runtime ──────────────────────────────────────────
FROM python:3.11.15-alpine3.22
# Install runtime dependencies
RUN apk add --no-cache \
        openjdk17-jre-headless \
        bash \
        libc6-compat
# Create application user/group (Alpine syntax)
RUN addgroup -g 1001 appgroup && \
    adduser -D -u 1001 -G appgroup appuser
# Create directories
RUN mkdir -p /template /opt/google/dataflow
# Copy Dataflow launcher
COPY --from=launcher \
    /opt/google/dataflow/python_template_launcher \
    /opt/google/dataflow/python_template_launcher
# Ensure launcher is executable
RUN chmod +x /opt/google/dataflow/python_template_launcher
# Copy application files
COPY requirements.txt /template/requirements.txt
COPY oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py
# Install Python dependencies
RUN pip install --no-cache-dir \
        --root-user-action=ignore \
        -r /template/requirements.txt
# Environment variables for Dataflow Flex Template
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"
ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE="/template/requirements.txt"
# Set ownership
RUN chown -R appuser:appgroup /template
# Switch to non-root user
USER appuser
WORKDIR /template
ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]