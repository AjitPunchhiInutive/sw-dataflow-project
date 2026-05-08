# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.11-alpine AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Alpine uses apk — NOT apt-get
# git        : required by dbt deps to resolve git-based package refs
# gcc/musl   : required to compile some Python C-extension packages
# libffi-dev : required by some dbt dependencies
RUN apk add --no-cache \
        git \
        gcc \
        musl-dev \
        libffi-dev \
        ca-certificates

# Install dbt and BigQuery adapter into an isolated prefix
RUN pip install --no-cache-dir --prefix=/install \
    dbt-core==1.9.1 \
    dbt-bigquery==1.9.0

# Copy dbt project files
WORKDIR /dbt
COPY dbt_project.yml .
COPY profiles.yml    .
COPY packages.yml    .
COPY models/         models/
COPY macros/         macros/
COPY tests/          tests/
COPY seeds/          seeds/
COPY snapshots/      snapshots/

# Bake dbt packages into image at build time
RUN PYTHONPATH=/install/lib/python3.11/site-packages \
    /install/bin/dbt deps --profiles-dir .

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM python:3.11-alpine AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Runtime only needs ca-certificates — no git, no gcc, no build tools
RUN apk add --no-cache ca-certificates

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy pre-built dbt project (includes dbt_packages/ from dbt deps)
COPY --from=builder /dbt /dbt

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Non-root user — Alpine uses adduser syntax
RUN adduser -D -H -s /sbin/nologin dbt
USER dbt

WORKDIR /dbt

ENTRYPOINT ["/entrypoint.sh"]