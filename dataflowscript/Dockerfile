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
        cargo \
        git && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt

# ── CVE fixes ──────────────────────────────────────────────────────────
# CVE-2026-3219  : pip ≤ 26.0.x
# CVE-2026-24049 : wheel ≤ 0.46.1
# CVE-2026-23949 : jaraco.context ≥ 5.2.0,< 6.1.0
# ───────────────────────────────────────────────────────────────────────
RUN pip install --no-cache-dir \
        "pip==26.1.1" \
        "setuptools==82.0.1" \
        "wheel==0.46.3" && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# ── Stage 3: clean runtime ───────────────────────────────────────────
FROM python:3.11.15-slim

RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── Upgrade pip/setuptools/wheel in the runtime layer too ─────────────
RUN pip install --no-cache-dir \
        "pip==26.1.1" \
        "setuptools==82.0.1" \
        "wheel==0.46.3"

# ── Create non-root user WITH a real home directory ───────────────────
# --no-create-home was the problem: pip, the launcher, and Beam all need
# a writable $HOME for caches and staging files.
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 \
            --gid appgroup \
            --create-home \
            --home-dir /home/appuser \
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

# Copy application files
COPY --chown=appuser:appgroup requirements.txt      /template/requirements.txt
COPY --chown=appuser:appgroup oden_pubsub_to_gcs.py /template/oden_pubsub_to_gcs.py

# Give appuser read+execute on /template and read-only on files
# 750 instead of 550 so the owner (appuser) retains full access
RUN chmod 750 /template && \
    chmod 440 /template/requirements.txt \
              /template/oden_pubsub_to_gcs.py

# Give appuser a writable home and cache directory
RUN mkdir -p /home/appuser/.cache && \
    chown -R appuser:appgroup /home/appuser

# ── Point tools at writable paths ─────────────────────────────────────
ENV HOME=/home/appuser \
    XDG_CACHE_HOME=/home/appuser/.cache \
    PIP_NO_CACHE_DIR=1 \
    TMPDIR=/tmp \
    FLEX_TEMPLATE_PYTHON_PY_FILE=/template/oden_pubsub_to_gcs.py \
    FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE=/template/requirements.txt

HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=15s \
            --retries=3 \
    CMD test -x /opt/google/dataflow/python_template_launcher || exit 1

WORKDIR /template

# ── Switch to non-root user ───────────────────────────────────────────
USER 1001

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]