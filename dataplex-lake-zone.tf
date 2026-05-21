module "dataplex_manufacturing" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex?ref=main"
  name       = "manufacturing"
  prefix     = "dev"
  project_id = "sw-dev-prj-sandbox"
  region     = "us-east4"

  zones = {
    # ── RDS Zone — RAW | sw-dev-udp-rds ───────────────────────────────────
    rds = {
      type      = "RAW"
      discovery = true
      assets = {
        bq-rds = {                        # ← was bq_rds
          resource_name          = "rds"
          cron_schedule          = "0 0 * * *"
          discovery_spec_enabled = true
          resource_spec_type     = "BIGQUERY_DATASET"
        }
      }
    },

    # ── EDS Zone — CURATED | sw-dev-udp-eds ───────────────────────────────
    eds = {
      type      = "CURATED"
      discovery = true
      assets = {
        bq-eds = {                        # ← was bq_eds (the failing key)
          resource_name          = "eds"
          cron_schedule          = null
          discovery_spec_enabled = false
          resource_spec_type     = "BIGQUERY_DATASET"
        }
      }
    },

    # ── ODS Zone — CURATED | sw-dev-udp-ods ───────────────────────────────
    ods = {
      type      = "CURATED"
      discovery = true
      assets = {
        bq-ods = {                        # ← was bq_ods
          resource_name          = "ods"
          cron_schedule          = null
          discovery_spec_enabled = false
          resource_spec_type     = "BIGQUERY_DATASET"
        }
      }
    }
  }
}