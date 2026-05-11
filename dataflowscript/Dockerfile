# ══════════════════════════════════════════════════════════════════════════════
# Multi-stage build — Google's official recommended pattern for reducing CVEs.
# Stage 1 CVEs DO NOT matter — only 1 binary is copied into the final image.
# All 600 CVEs from the Dataflow base stay in Stage 1 and are discarded.
# ══════════════════════════════════════════════════════════════════════════════

# ── Stage 1: Extract launcher binary only ────────────────────────────────────
# Your original working tag. Used ONLY to get the launcher binary (64KB).
# The 600 CVEs in this image NEVER reach the final image — only the binary crosses.
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:20260122-rc00 AS launcher

# ── Stage 2: Clean low-CVE runtime ───────────────────────────────────────────
# apache/beam_python3.11_sdk is purpose-built for Dataflow, actively patched,
# and ships with far fewer OS packages than the full Dataflow base image.
FROM apache/beam_python3.11_sdk:2.62.0

# ── Copy ONLY the launcher binary from Stage 1 ───────────────────────────────
# This single COPY is the only thing Stage 1 contributes to the final image.
# Everything else in the 600-CVE Dataflow base is thrown away.
COPY --from=launcher /opt/google/dataflow/python_template_launcher \
                     /opt/google/dataflow/python_template_launcher

# ── Patch all base OS packages immediately ────────────────────────────────────
RUN apt-get update -qq && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        default-jre-headless \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ── Upgrade pip ───────────────────────────────────────────────────────────────
RUN pip install --no-cache-dir --upgrade pip

# ── Create non-root user ──────────────────────────────────────────────────────
RUN groupadd --gid 1001 appgroup && \
    useradd  --uid 1001 \
             --gid appgroup \
             --no-create-home \
             --shell /sbin/nologin \
             appuser

# ── Set template env vars ─────────────────────────────────────────────────────
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/oden_pubsub_to_gcs.py"

# ── Copy files with restricted ownership ─────────────────────────────────────
COPY --chown=appuser:appgroup requirements.txt       /template/requirements.txt
COPY --chown=appuser:appgroup oden_pubsub_to_gcs.py  /template/oden_pubsub_to_gcs.py

# ── Lock down permissions ─────────────────────────────────────────────────────
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

USER appuser
WORKDIR /template
ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]