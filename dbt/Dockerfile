# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.11-alpine AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# FIX CVE-2026-34743: upgrade xz to >=5.8.3 (heap buffer overflow in lzma_index_append)
RUN apk add --no-cache \
        git \
        gcc \
        musl-dev \
        libffi-dev \
        ca-certificates \
        bash \
    && apk upgrade --no-cache xz

# FIX CVE-2025-8869, CVE-2026-1703, CVE-2026-3219: pip>=26.1 (tar symlink traversal,
#     wheel path traversal, concatenated tar+ZIP confusion)
# FIX CVE-2026-23949, CVE-2026-6357: setuptools>=80.10.1 (jaraco.context Zip Slip,
#     PackageIndex path traversal)
# FIX CVE-2026-24049: wheel>=0.46.2 (arbitrary file permission modification)
RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=80.10.1" \
        "wheel>=0.46.2"

# FIX CVE-2026-29790: dbt-common>=1.37.3 (os.path.commonprefix() path traversal in safe_extract)
# FIX CVE-2025-58367, CVE-2026-33155: deepdiff>=8.6.2 (class pollution RCE + memory exhaustion DoS)
# Install pinned safe versions of transitive dependencies BEFORE dbt itself
RUN pip install --no-cache-dir --prefix=/install \
        "dbt-common>=1.37.3" \
        "deepdiff>=8.6.2"

RUN pip install --no-cache-dir --prefix=/install \
    dbt-core==1.9.1 \
    dbt-bigquery==1.9.0

WORKDIR /dbt
COPY dbt_project.yml .
COPY profiles.yml    .
COPY packages.yml    .
COPY models/         models/
COPY macros/         macros/
COPY tests/          tests/
COPY seeds/          seeds/
COPY snapshots/      snapshots/

RUN PYTHONPATH=/install/lib/python3.11/site-packages \
    /install/bin/dbt deps --profiles-dir .

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM python:3.11-alpine AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_LOG_PATH=/dbt/logs \
    DBT_PROFILES_DIR=/dbt

# FIX CVE-2026-34743 in runtime image as well: upgrade xz
RUN apk add --no-cache \
        ca-certificates \
        bash \
    && apk upgrade --no-cache xz

# Upgrade pip/setuptools/wheel in the runtime Python environment too
# so any runtime pip invocations (e.g. dbt deps) use patched versions
RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=80.10.1" \
        "wheel>=0.46.2"

# Create non-root user BEFORE setting permissions
RUN adduser -D -H -s /sbin/nologin dbt

COPY --from=builder /install /usr/local

# Copy dbt project owned by dbt user from the start
COPY --chown=dbt:dbt --from=builder /dbt /dbt

# Create all directories dbt needs to write to at runtime
RUN mkdir -p \
        /dbt/logs \
        /dbt/target \
        /dbt/dbt_packages \
    && chown -R dbt:dbt \
        /dbt/logs \
        /dbt/target \
        /dbt/dbt_packages \
    && chmod -R 755 \
        /dbt/logs \
        /dbt/target \
        /dbt/dbt_packages

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r//' /entrypoint.sh && \
    chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=10s \
            --retries=3 \
    CMD bash -c " \
        test -x /usr/local/bin/dbt        || exit 1; \
        test -x /entrypoint.sh            || exit 1; \
        python --version > /dev/null 2>&1 || exit 1; \
        dbt --version > /dev/null 2>&1    || exit 1 \
    "

USER dbt

WORKDIR /dbt

ENTRYPOINT ["/entrypoint.sh"]