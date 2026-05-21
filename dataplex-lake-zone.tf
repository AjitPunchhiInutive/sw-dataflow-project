module "dataplex_manufacturing" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex?ref=main"
  name       = "manufacturing"
  prefix     = "dev"
  project_id = "sw-dev-prj-sandbox"
  region     = "us-east4"
  description = "The Manufacturing Lake  defines the governance boundary for Southwire manufacturing data. It provides a consistent structure for organizing and discovering manufacturing data across raw and curated lifecycle stages."

  zones = {
    # ── RDS Zone — RAW | sw-dev-udp-rds ───────────────────────────────────
    rds = {
      type      = "RAW"
      discovery = true
      assets = {
        bq_rds = {
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
        bq_eds = {
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
        bq_ods = {
          resource_name          = "ods"
          cron_schedule          = null
          discovery_spec_enabled = false
          resource_spec_type     = "BIGQUERY_DATASET"
        }
      }
    }
  }
}