# ══════════════════════════════════════════════════════════════════════════════
# This is the pattern recommended in Google's official Dataflow docs:
# https://cloud.google.com/dataflow/docs/guides/templates/configuring-flex-templates
#
# Stage 1: Pull ONLY the launcher binary from the Dataflow base image.
# Stage 2: Use apache/beam SDK as the clean, actively-patched runtime.
#
# Why this reduces CVEs:
#   - The full Dataflow base ships with hundreds of OS-level packages → 600 CVEs
#   - apache/beam SDK is purpose-built, minimal, regularly patched → ~100-150 CVEs
#   - Only 1 binary (64KB) crosses from Stage 1 into Stage 2
# ══════════════════════════════════════════════════════════════════════════════

# ── Stage 1: Launcher binary extraction ──────────────────────────────────────
# Latest patched tag per Google's official release table (20251006_RC00).
# Nothing from this stage reaches the final image except the launcher binary.
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:20251006_RC00 AS launcher

# ── Stage 2: Clean runtime ────────────────────────────────────────────────────
# apache/beam_python3.11_sdk is actively maintained by Apache Beam team.
# It is purpose-built for Dataflow, has prebuilt wheels for beam/pyarrow/pandas,
# and has significantly fewer OS packages than the full Dataflow base image.
FROM apache/beam_python3.11_sdk:2.62.0

# ── Copy ONLY the launcher binary from Stage 1 ───────────────────────────────
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