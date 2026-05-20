# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.13.13-alpine3.22 AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk add --no-cache \
        git \
        gcc \
        musl-dev \
        libffi-dev \
        ca-certificates \
        bash \
        'xz>=5.8.3'

RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=82.0.1" \
        "wheel>=0.46.2"

RUN pip install --no-cache-dir --prefix=/install \
        "dbt-common>=1.37.3" \
        "deepdiff>=8.6.2"

RUN pip install --no-cache-dir --prefix=/install \
        "dbt-core==1.11.11" \
        "dbt-bigquery==1.11.1"

WORKDIR /dbt
COPY dbt_project.yml .
COPY profiles.yml    .
COPY packages.yml    .
COPY models/         models/
COPY macros/         macros/
COPY tests/          tests/
COPY seeds/          seeds/
COPY snapshots/      snapshots/

RUN PYTHONPATH=/install/lib/python3.13/site-packages \
    /install/bin/dbt deps --profiles-dir .

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM python:3.13.13-alpine3.22 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_LOG_PATH=/dbt/logs \
    DBT_PROFILES_DIR=/dbt

RUN apk add --no-cache \
        ca-certificates \
        bash \
        'xz>=5.8.3'

# Same floor applied here — the runtime image's pip comes from the base layer
# and is independent of the builder stage.
RUN pip install --no-cache-dir \
        "pip>=26.1" \
        "setuptools>=82.0.1" \
        "wheel>=0.46.2"

RUN pip install --no-cache-dir \
        "dbt-common>=1.37.3" \
        "deepdiff>=8.6.2"

RUN adduser -D -H -s /sbin/nologin dbt

COPY --from=builder /install /usr/local

COPY --chown=dbt:dbt --from=builder /dbt /dbt

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