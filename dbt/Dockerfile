# =============================================================================
# Dockerfile — dbt BigQuery Cloud Run Image
# =============================================================================
# PURPOSE:
#   Packages the dbt project into a self-contained Docker image that Cloud Run
#   executes as a Job. Every dbt dependency, project file, and the entrypoint
#   script are baked in at build time so the container needs no internet access
#   at runtime except to reach BigQuery.
#
# WHERE THIS RUNS:
#   - Built locally (or in CI) with: docker buildx build --platform linux/amd64
#   - Pushed to Google Artifact Registry
#   - Pulled and executed by Cloud Run Job on demand
#
# WHAT GETS INSTALLED HERE (build time, not runtime):
#   - dbt-core      : dbt CLI and framework
#   - dbt-bigquery  : BigQuery adapter — translates dbt SQL to BQ API calls
#   - dbt_utils     : installed via `dbt deps` from packages.yml
# =============================================================================

# Base image: official Python 3.11 slim — small footprint, no unnecessary tools
FROM gcr.io/dataflow-templates-base/python311-template-launcher-base:20260122-rc00

# Prevent Python from writing .pyc files (keeps image clean)
# Ensure stdout/stderr are unbuffered so logs appear immediately in Cloud Run
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# git is required by dbt during `dbt deps` to resolve package versions from git refs
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# Install dbt and the BigQuery adapter.
# dbt-core     : the dbt CLI — parses models, builds DAGs, runs tests
# dbt-bigquery : adapter that connects dbt to BigQuery via the BQ Python SDK
# Pinned to exact versions so builds are reproducible across environments.
RUN pip install --no-cache-dir \
    dbt-core==1.9.1 \
    dbt-bigquery==1.9.0

# All dbt project files are placed under /dbt inside the container.
# profiles.yml and dbt_project.yml must be in the same directory for
# the --profiles-dir /dbt flag in entrypoint.sh to resolve correctly.
WORKDIR /dbt

# Copy dbt project configuration and all model/macro/test directories.
# Each COPY is a separate layer — changes to models don't invalidate
# the pip install layer above, keeping rebuilds fast.
COPY dbt_project.yml .
COPY profiles.yml .
COPY packages.yml .
COPY models/     models/
COPY macros/     macros/
COPY tests/      tests/
COPY seeds/      seeds/
COPY snapshots/  snapshots/

# Copy the entrypoint script that decides what dbt command to run.
# Placed at /entrypoint.sh (outside /dbt) to keep it separate from dbt project files.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Install dbt packages declared in packages.yml (e.g. dbt_utils).
# This runs at BUILD time so packages are baked into the image — the container
# does not need to download anything when it starts in Cloud Run.
# --profiles-dir . tells dbt where profiles.yml is during this build step.
RUN dbt deps --profiles-dir .

# The entrypoint script is the single entry point for all container executions.
# Cloud Run Job executes this script on startup. Composer can override the
# default args to run specific dbt commands (run, test, build, etc.).
ENTRYPOINT ["./dbt/entrypoint.sh"]
