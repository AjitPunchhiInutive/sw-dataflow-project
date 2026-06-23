# ── Stage 1: Dataflow launcher binary ─────────────────────────────────
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:20260413-rc01 AS launcher

# ── Stage 2: build Python dependencies (throwaway) ───────────────────
FROM python:3.11.15-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        build-essential \
        libffi-dev \
        libc6-dev \
        libssl-dev \
        pkg-config \
        cargo \
        git && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt

# ── CVE fixes ──────────────────────────────────────────────────────────
# CVE-2026-3219  : pip ≤ 26.0.x  — concatenated tar+ZIP treated as ZIP
#                  → upgrade to pip 26.1.2
# CVE-2026-6357  : pip < 26.1 — self-update imports from installed wheel
#                  → upgrade to pip 26.1.2
# CVE-2026-24049 : wheel ≤ 0.46.1 — path traversal in wheel unpack
#                  → upgrade to wheel 0.46.3
# CVE-2026-23949 : jaraco.context ≥ 5.2.0,< 6.1.0 (vendored in setuptools)
#                  — Zip Slip in tarball() function
#                  → upgrade to setuptools 82.0.1 (vendors jaraco.context 6.1.0+)
# CVE-2026-25087 : pyarrow 15.0.0–23.0.0 — Use-After-Free in Arrow IPC
#                  → upgrade to pyarrow ≥ 23.0.1
# GHSA-537c-gmf6-5ccf : cryptography < 48.0.1 — vulnerable bundled OpenSSL
#                  → upgrade to cryptography ≥ 48.0.1
# ───────────────────────────────────────────────────────────────────────
RUN pip install --no-cache-dir \
        "pip==26.1.2" \
        "setuptools==82.0.1" \
        "wheel==0.46.3" && \
    # ── Override vulnerable pins in requirements.txt before install ────
    sed -i 's/^pyarrow[=<>!].*/pyarrow>=23.0.1/' /tmp/requirements.txt && \
    sed -i 's/^cryptography[=<>!].*/cryptography>=48.0.1/' /tmp/requirements.txt && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# ── Stage 3: clean runtime (no build tools, no libmbedtls) ───────────
FROM python:3.11.15-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── Upgrade pip/setuptools/wheel in the runtime layer too ─────────────
# The base python:3.11.15-slim ships its own bundled pip.
# Overwrite it with the same patched versions used in the builder stage
# so scanners don't flag the base-image pip binary.
RUN pip install --no-cache-dir \
        "pip==26.1.2" \
        "setuptools==82.0.1" \
        "wheel==0.46.3"

# Create non-root user and group
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 \
            --gid appgroup \
            --no-create-home \
            --shell /sbin/nologin \
            appuser

# Copy the launcher binary
COPY --from=launcher \
    /opt/google/dataflow/python_template_launcher \
    /opt/google/dataflow/python_template_launcher
RUN chmod +x /opt/google/dataflow/python_template_launcher

# Copy compiled Python packages from the builder
COPY --from=builder /usr/local/lib/python3.11/site-packages \
                    /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application files with ownership set at copy time
COPY --chown=appuser:appgroup requirements.txt      /template/requirements.txt
COPY --chown=appuser:appgroup oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py

# Tighten permissions: owner+group read/execute on dir, read-only on files
RUN chmod 550 /template && \
    chmod 440 /template/requirements.txt \
              /template/oden_pubsub_to_gcs.py

ENV FLEX_TEMPLATE_PYTHON_PY_FILE=/template/oden_pubsub_to_gcs.py
#ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE=/template/requirements.txt

HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=15s \
            --retries=3 \
    CMD test -x /opt/google/dataflow/python_template_launcher || exit 1

WORKDIR /template

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]