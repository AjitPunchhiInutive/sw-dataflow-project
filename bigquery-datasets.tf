# ── BigQuery Dataset (Destination) ───────────────────────────────────────────
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

resource "google_bigquery_routine" "sp_clone_all_tables" {
  project      = "sw-dev-prj-sandbox"
  dataset_id   = "pubsub_gcs_dataflow"
  routine_id   = "sp_clone_all_tables"
  routine_type = "PROCEDURE"
  language     = "SQL"

  arguments {
    name      = "src_project"
    mode      = "IN"
    data_type = jsonencode({ typeKind = "STRING" })
  }
  arguments {
    name      = "src_dataset"
    mode      = "IN"
    data_type = jsonencode({ typeKind = "STRING" })
  }
  arguments {
    name      = "dest_project"
    mode      = "IN"
    data_type = jsonencode({ typeKind = "STRING" })
  }
  arguments {
    name      = "dest_dataset"
    mode      = "IN"
    data_type = jsonencode({ typeKind = "STRING" })
  }

  definition_body = <<-EOT
    DECLARE table_list ARRAY<STRING>;
    DECLARE i          INT64 DEFAULT 0;
    DECLARE table_name STRING;

    EXECUTE IMMEDIATE FORMAT(
      '''
      SELECT ARRAY_AGG(table_name)
      FROM `%s.%s.INFORMATION_SCHEMA.TABLES`
      WHERE table_type = 'BASE TABLE'
      ''',
      src_project, src_dataset
    )
    INTO table_list;

    WHILE i < ARRAY_LENGTH(table_list) DO
      SET table_name = table_list[OFFSET(i)];
      EXECUTE IMMEDIATE FORMAT(
        'CREATE OR REPLACE TABLE `%s.%s.%s` CLONE `%s.%s.%s`',
        dest_project, dest_dataset, table_name,
        src_project,  src_dataset,  table_name
      );
      SET i = i + 1;
    END WHILE;
  EOT

  depends_on = [module.bigquery-dataset-copyjob]
}

resource "google_bigquery_job" "invoke_sp_clone_all_tables" {
  project  = "sw-dev-prj-sandbox"
  job_id   = "invoke_sp_clone_all_tables_3"
  location = "us-east4"

  query {
    query = <<-EOT
      DECLARE src_project  STRING DEFAULT 'sw-dev-prj-sandbox';
      DECLARE src_dataset  STRING DEFAULT 'pubsub_gcs_dataflow';
      DECLARE dest_project STRING DEFAULT 'sw-dev-prj-itp-secrets';
      DECLARE dest_dataset STRING DEFAULT 'copyjob_streaming_dataset';

      CALL `sw-dev-prj-sandbox.pubsub_gcs_dataflow.sp_clone_all_tables`(
        src_project,
        src_dataset,
        dest_project,
        dest_dataset
      );
    EOT

    use_legacy_sql   = false
    create_disposition = ""
    write_disposition  = ""
  }
  depends_on = [google_bigquery_routine.sp_clone_all_tables]

  lifecycle {
    replace_triggered_by = [google_bigquery_routine.sp_clone_all_tables]
  }
}

# ── BigQuery Scheduled Query — Nightly Dev Reset ──────────────────────────────
# Runs every day at 03:00 UTC
# Calls sp_clone_all_tables to clone tables from dev → itp-secrets
resource "google_bigquery_data_transfer_config" "nightly_dev_reset" {
  project                = "sw-dev-prj-sandbox"
  location               = "us-east4"
  display_name           = "Nightly-Dev-Reset"
  data_source_id         = "scheduled_query"          # BigQuery native scheduled query
  schedule               = "every 24 hours"           # runs daily at 03:00 UTC
  schedule_options {
     start_time = timeadd(timestamp(), "24h")               # first run at 03:00 UTC
  }

  params = {
    query = <<-EOT
      DECLARE src_project  STRING DEFAULT 'sw-dev-prj-sandbox';
      DECLARE src_dataset  STRING DEFAULT 'pubsub_gcs_dataflow';
      DECLARE dest_project STRING DEFAULT 'sw-dev-prj-itp-secrets';
      DECLARE dest_dataset STRING DEFAULT 'copyjob_streaming_dataset';

      CALL `sw-dev-prj-sandbox.pubsub_gcs_dataflow.sp_clone_all_tables`(
        src_project,
        src_dataset,
        dest_project,
        dest_dataset
      );
    EOT
  }

  # Service account that runs the scheduled query
  service_account_name = "dataflow-runner@sw-dev-prj-sandbox.iam.gserviceaccount.com"

  depends_on = [google_bigquery_routine.sp_clone_all_tables]
}