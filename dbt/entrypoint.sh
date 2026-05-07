#!/bin/bash
# =============================================================================
# entrypoint.sh — Container Entry Point for dbt Execution
# =============================================================================
# PURPOSE:
#   This script is the ENTRYPOINT of the Docker container. It is the first
#   thing that runs when Cloud Run starts the container. Its job is to decide
#   what dbt command to execute based on how the container was invoked.
#
# TWO MODES OF OPERATION:
#
#   1. DEFAULT (no args passed) — used when triggering the job manually:
#      Runs the full pipeline: dbt run followed by dbt test.
#      Example: gcloud run jobs execute dbt-run-job
#
#   2. OVERRIDE (args passed by Composer) — used when Airflow triggers the job:
#      Runs only the specific dbt command passed by CloudRunExecuteJobOperator.
#      The DAG passes args like ["run", "--profiles-dir", "/dbt", "--target", "prod"]
#      which override the default CMD and flow into $@ here.
#      Example trigger from DAG task:
#        overrides: { container_overrides: [{ args: ["run", "--profiles-dir", "/dbt"] }] }
#
# FLAGS EXPLAINED:
#   --profiles-dir /dbt  : tells dbt where to find profiles.yml (authentication config)
#   --project-dir /dbt   : tells dbt where dbt_project.yml lives (model definitions)
#   --target prod        : selects the 'prod' output block in profiles.yml
#                          prod uses /secrets/sa-key.json mounted from Secret Manager
# =============================================================================

set -e  # Exit immediately if any command returns a non-zero status

echo "============================================"
echo "  dbt GCP POC — Container Execution"
echo "============================================"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Check if arguments were passed to the container (i.e. Composer is overriding)
if [ $# -gt 0 ]; then
    # OVERRIDE MODE: Composer (or any caller) passed specific dbt args.
    # $@ contains all the args, e.g.: run --profiles-dir /dbt --target prod
    # This allows Airflow to run dbt_run and dbt_test as separate tasks,
    # giving independent retry and monitoring per task in the Airflow UI.
    echo "Running custom command: dbt $@"
    echo "--------------------------------------------"
    dbt "$@" --profiles-dir /dbt --project-dir /dbt
else
    # DEFAULT MODE: No args — run the full pipeline sequentially.
    # Used for manual testing via: gcloud run jobs execute dbt-run-job --wait
    echo "Running default pipeline: dbt run → dbt test"
    echo "--------------------------------------------"

    echo ""
    echo ">>> Step 1: dbt run"
    # dbt run materializes all models in dependency order:
    # eds_stg_customers (view) → eds_stg_orders (view) → ods_customer_orders (table)
    dbt run --profiles-dir /dbt --project-dir /dbt --target prod

    echo ""
    echo ">>> Step 2: dbt test"
    # dbt test runs all data quality tests defined in _eds_models.yml and _ods_models.yml:
    # unique, not_null, accepted_values checks on key columns
    dbt test --profiles-dir /dbt --project-dir /dbt --target prod

    echo ""
    echo "============================================"
    echo "  Pipeline completed successfully!"
    echo "============================================"
fi
