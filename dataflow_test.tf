module "gcs" {
  source        = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//gcs?ref=main"
  project_id    = var.test_project_id
  name          = "sw-test-dataflow-gcs-itp"
  location      = "us-east4"
  versioning    = false
  force_destroy = false
  labels = {
    cost-center = "devops"
  }
}

resource "google_storage_bucket_object" "myfiles" {
  bucket       = module.gcs.name
  name         = "templates/"
  content      = " "
  content_type = "application/x-directory"
}

module "bigquery-dataset" {
  source = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//bigquery-dataset?ref=main"

  project_id    = var.test_project_id
  id            = "pubsub_gcs_dataflow"
  friendly_name = "SW Pubsub Dataset test"
  description   = "SW Pubsub Dataset test"
  location      = "us-east4"

  options = {
    default_table_expiration_ms     = null
    default_partition_expiration_ms = null
    delete_contents_on_destroy      = false
  }

  tables = {
    historian_stream = {
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
    }

    historian_stream_error = {
      friendly_name       = "Historian Stream Error"
      deletion_protection = true
      schema = jsonencode([
        { name = "publish_time",   type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "ingestion_time", type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "raw_payload",    type = "STRING",    mode = "NULLABLE" },
        { name = "error_message",  type = "STRING",    mode = "NULLABLE" }
      ])
    }
    historian_stream_backupjob = {
      friendly_name       = "Historian Stream backupjob"
      deletion_protection = true
      schema = jsonencode([
        { name = "publish_time",   type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "ingestion_time", type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "raw_payload",    type = "STRING",    mode = "NULLABLE" },
        { name = "error_message",  type = "STRING",    mode = "NULLABLE" }
      ])
    }
    historian_stream_demo = {
      friendly_name       = "Historian Stream demo"
      deletion_protection = true
      schema = jsonencode([
        { name = "publish_time",   type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "ingestion_time", type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "raw_payload",    type = "STRING",    mode = "NULLABLE" },
        { name = "error_message",  type = "STRING",    mode = "NULLABLE" }
      ])
    }
  }
}
module "docker_artifact_registry"{
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//artifact-registry?ref=main"
  project_id = var.test_project_id
  location   = "us-east4"
  name       = "sw-test-dataflow-template"
  format     = { docker = { standard = {} } }

  labels = {
    managed-by = "terraform"
    purpose    = "dataflow-templates"
  }
}
