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
# CVE-2026-3219  : pip ≤ 26.0.x  → upgrade to pip 26.1.1
# CVE-2026-24049 : wheel ≤ 0.46.1 → upgrade to wheel 0.46.3
# CVE-2026-23949 : setuptools < 82.0.1 → upgrade to setuptools 82.0.1
# ───────────────────────────────────────────────────────────────────────
RUN pip install --no-cache-dir \
        "pip==26.1.2" \
        "setuptools==82.0.1" \
        "wheel==0.46.3" && \
    sed -i 's/^pyarrow[=<>!].*/pyarrow>=23.0.1/' /tmp/requirements.txt && \
    sed -i 's/^cryptography[=<>!].*/cryptography<=48.0.1/' /tmp/requirements.txt && \
    pip install --no-cache-dir -r /tmp/requirements.txt
 
# ── Stage 3: clean runtime (glibc — required by Dataflow launcher) ────
FROM python:3.11.15-slim
 
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends default-jre-headless && \
    # ── CVE-2026-12087: purge ALL perl packages regardless of version ──
    PERL_PKGS="$(dpkg-query -W -f='${Package}\n' 2>/dev/null \
        | grep -E '^(perl|perl-base|perl-modules.*|libperl[0-9].*|libsocket-perl)$' || true)" && \
    if [ -n "$PERL_PKGS" ]; then \
        dpkg --purge --force-depends $PERL_PKGS 2>/dev/null || true; \
    fi && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
           /usr/bin/perl* \
           /usr/lib/*/perl* \
           /usr/lib/*/perl-base \
           /usr/lib/perl* \
           /usr/share/perl*
 
# ── Upgrade pip/setuptools/wheel in the runtime layer too ─────────────
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
 
# Tighten permissions
RUN chmod 550 /template && \
    chmod 440 /template/requirements.txt \
              /template/oden_pubsub_to_gcs.py
 
ENV FLEX_TEMPLATE_PYTHON_PY_FILE=/template/oden_pubsub_to_gcs.py
 
HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=15s \
            --retries=3 \
    CMD test -x /opt/google/dataflow/python_template_launcher || exit 1
 
WORKDIR /template
 
ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]