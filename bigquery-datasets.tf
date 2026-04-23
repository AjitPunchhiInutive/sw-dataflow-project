# ── Dataset 1: Historian Streaming Dataset ────────────────────────────────────
module "bigquery-dataset-copyjob" {
  source = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//bigquery-dataset?ref=main"

  project_id    = "sw-dev-prj-itp-secrets"
  id            = "copyjob_streaming_dataset"
  friendly_name = "SW copyjob Streaming Dataset"
  description   = "SW copyjob Streaming Dataset - Main streaming tables"
  location      = "us-east4"

  options = {
    default_table_expiration_ms     = null
    default_partition_expiration_ms = null
    delete_contents_on_destroy      = false
  }
}