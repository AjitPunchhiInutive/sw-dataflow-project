#!/bin/bash
# =============================================================================
# entrypoint.sh — Container Entry Point for dbt Execution
# =============================================================================
# KEYLESS: No key file handling needed. The container authenticates via ADC
# automatically because Cloud Run Job runs AS the dbt-bigquery-sa SA.
#
# TARGET RESOLUTION:
#   The active dbt target (dev/uat/prod) is read from DBT_TARGET env var.
#   This env var is set by deploy_cloudrun.sh via --set-env-vars at deploy time.
#   Composer overrides per-task args, which include --target $DBT_TARGET.
#
# TWO MODES:
#   DEFAULT (no args): full pipeline — dbt run → dbt test
#   OVERRIDE (args from Composer): runs the specific command passed
# =============================================================================

set -e

# DBT_TARGET is injected by Cloud Run as an env var from configs/ENV.yml.
# Falls back to 'dev' if not set (safe default for local runs).
TARGET="${DBT_TARGET:-dev}"

echo "============================================"
echo "  dbt Execution"
echo "============================================"
echo "Timestamp:   $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Environment: ${TARGET}"
echo "Project:     ${GCP_PROJECT_ID:-not set}"
echo "Dataset:     ${DBT_DATASET_PREFIX:-not set}"
echo ""

if [ $# -gt 0 ]; then
    # OVERRIDE MODE: Composer passed specific dbt args.
    # e.g. args: ["run", "--profiles-dir", "/dbt", "--target", "prod"]
    echo "Running custom command: dbt $@"
    echo "--------------------------------------------"
    dbt "$@" --profiles-dir /dbt --project-dir /dbt
else
    # DEFAULT MODE: full pipeline for manual execution / testing
    echo "Running default pipeline: dbt run → dbt test"
    echo "--------------------------------------------"

    echo ""
    echo ">>> Step 1: dbt run"
    dbt run --profiles-dir /dbt --project-dir /dbt --target "${TARGET}"

    echo ""
    echo ">>> Step 2: dbt test"
    dbt test --profiles-dir /dbt --project-dir /dbt --target "${TARGET}"

    echo ""
    echo "============================================"
    echo "  Pipeline completed successfully!"
    echo "============================================"
fi
