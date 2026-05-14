# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.11-alpine AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk add --no-cache \
        git \
        gcc \
        musl-dev \
        libffi-dev \
        ca-certificates \
        bash

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

# bash is required — entrypoint.sh uses #!/bin/bash
RUN apk add --no-cache \
        ca-certificates \
        bash

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

# ── Health Check ──────────────────────────────────────────────────────────────
# Cloud Run Jobs have no HTTP endpoint so we probe key binaries directly:
#   1. dbt binary exists and is executable
#   2. entrypoint.sh exists and is executable
#   3. python is available
# start-period=10s gives the container time to initialise before first check.
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

# Drop to non-root AFTER all permission setup is done
USER dbt

WORKDIR /dbt

ENTRYPOINT ["/entrypoint.sh"]