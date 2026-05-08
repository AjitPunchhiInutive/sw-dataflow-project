# ── Stage 1: Builder ──────────────────────────────────────────────────────────
# Full slim image — has apt-get, pip, shell. Used ONLY to install dependencies.
# Nothing from this stage reaches production except the installed packages.
FROM python:3.11-alpine AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install git (required by dbt deps to resolve git-based package refs)
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install dbt and BigQuery adapter into an isolated prefix
# so we can copy them cleanly into the runtime stage
RUN pip install --no-cache-dir --prefix=/install \
    dbt-core==1.9.1 \
    dbt-bigquery==1.9.0

# Copy dbt project files for dbt deps
WORKDIR /dbt
COPY dbt_project.yml .
COPY profiles.yml    .
COPY packages.yml    .
COPY models/         models/
COPY macros/         macros/
COPY tests/          tests/
COPY seeds/          seeds/
COPY snapshots/      snapshots/

# Bake dbt packages into the image at build time — container needs no internet at runtime
RUN PYTHONPATH=/install/lib/python3.11/site-packages \
    /install/bin/dbt deps --profiles-dir .

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
# Clean slim image — no build tools, no apt cache, no git, fewer CVEs.
# Only carries what's needed to actually run dbt.
FROM python:3.11-alpine AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy pre-built dbt project (including dbt_packages from dbt deps)
COPY --from=builder /dbt /dbt

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run as non-root user — security best practice for Cloud Run
RUN useradd --no-create-home --shell /bin/false dbt
USER dbt

WORKDIR /dbt

ENTRYPOINT ["/entrypoint.sh"]