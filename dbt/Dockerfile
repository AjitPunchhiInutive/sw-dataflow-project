# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.11-alpine AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk add --no-cache \
        git \
        gcc \
        musl-dev \
        libffi-dev \
        ca-certificates

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

RUN apk add --no-cache ca-certificates

# Create non-root user BEFORE setting permissions
RUN adduser -D -H -s /sbin/nologin dbt

COPY --from=builder /install /usr/local

# Copy dbt project owned by dbt user from the start
COPY --chown=dbt:dbt --from=builder /dbt /dbt

# Create all directories dbt needs to write to at runtime
# and give ownership to dbt user — must be done as root BEFORE USER switch
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

# Drop to non-root AFTER all permission setup is done
USER dbt

WORKDIR /dbt

ENTRYPOINT ["/entrypoint.sh"]