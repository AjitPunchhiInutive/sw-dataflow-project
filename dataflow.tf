module "gcs_python" {
  source        = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//gcs?ref=main"
  project_id    = var.log_project_id
  name          = "sw-rds-dataflow-gcs-itp"
  location      = "us-east4"
  versioning    = false
  force_destroy = false
  labels = {
    cost-center = "devops"
  }
}

resource "google_storage_bucket_object" "files" {
  bucket       = module.gcs_python.name
  name         = "templates/"
  content      = " "
  content_type = "application/x-directory"
}

# ── Dataset only (no tables inside the module) ──────────────────────────────
module "bigquery-dataset" {
  source = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//bigquery-dataset?ref=main"

  project_id    = var.log_project_id
  id            = "pubsub_gcs_dataflow"
  friendly_name = "SW Pubsub Dataset test"
  description   = "SW Pubsub Dataset test"
  location      = "us-east4"

  options = {
    default_table_expiration_ms     = null
    default_partition_expiration_ms = null
    delete_contents_on_destroy      = false
  }

  tables = {}   # ← tables managed separately below to prevent recreation
}

# ── Tables managed directly with lifecycle protection ────────────────────────

resource "google_bigquery_table" "historian_stream" {
  project             = var.log_project_id
  dataset_id          = module.bigquery-dataset.dataset_id
  table_id            = "historian_stream"
  friendly_name       = "Historian Stream"
  deletion_protection = true

  schema = jsonencode([
    { name = "messageid",      type = "INT64",     mode = "NULLABLE" },
    { name = "status",         type = "INT64",     mode = "NULLABLE" },
    { name = "tagname",        type = "STRING",    mode = "NULLABLE" },
    { name = "epochtime",      type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "tagvalue",       type = "STRING",    mode = "NULLABLE" },
    { name = "quality",        type = "INT64",     mode = "NULLABLE" },
    { name = "sq",             type = "STRING",    mode = "NULLABLE" },
    { name = "publish_time",   type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "ingestion_time", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "rowhash",        type = "STRING",    mode = "NULLABLE" }
  ])

  lifecycle {
    prevent_destroy = true          # ← Terraform will hard-error if destroy attempted
    ignore_changes  = [schema]      # ← schema drift won't trigger recreation
  }

  depends_on = [module.bigquery-dataset]
}

resource "google_bigquery_table" "historian_stream_error" {
  project             = var.log_project_id
  dataset_id          = module.bigquery-dataset.dataset_id
  table_id            = "historian_stream_error"
  friendly_name       = "Historian Stream Error"
  deletion_protection = true

  schema = jsonencode([
    { name = "publish_time",   type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "ingestion_time", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "raw_payload",    type = "STRING",    mode = "NULLABLE" },
    { name = "error_message",  type = "STRING",    mode = "NULLABLE" }
  ])

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [schema]
  }

  depends_on = [module.bigquery-dataset]
}

resource "google_bigquery_table" "historian_stream_demo" {
  project             = var.log_project_id
  dataset_id          = module.bigquery-dataset.dataset_id
  table_id            = "historian_stream_demo"
  friendly_name       = "Historian Stream Demo"
  deletion_protection = true

  schema = jsonencode([
    { name = "publish_time",   type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "ingestion_time", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "raw_payload",    type = "STRING",    mode = "NULLABLE" },
    { name = "error_message",  type = "STRING",    mode = "NULLABLE" }
  ])

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [schema]
  }

  depends_on = [module.bigquery-dataset]
}

module "pubsub" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//pubsub?ref=main"
  project_id = var.log_project_id
  name       = "pubsub-historian-dataflow_topic"
  message_retention_duration = "604800s"
  subscriptions = {
    "proficy-historian-topic" = {
      ack_deadline_seconds         = 20
      message_retention_duration   = "604800s" # 7 days
      retain_acked_messages        = false
      filter                       = null
      enable_message_ordering      = false
      enable_exactly_once_delivery = false
      expiration_policy_ttl        = null
      push                         = null
      bigquery                     = null
      cloud_storage                = null
      dead_letter_policy           = null
      retry_policy = {
        minimum_backoff = 10  # seconds
        maximum_backoff = 600 # seconds
      }
    }
  }
}
module "docker_artifact_registry"{
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//artifact-registry?ref=main"
  project_id = var.log_project_id
  location   = "us-east4"
  name       = "sw-dataflow-template"
  format     = { docker = { standard = {} } }

  labels = {
    managed-by = "terraform"
    purpose    = "dataflow-templates"
  }
}
