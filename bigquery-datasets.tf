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

# ── Routine 1: Core Procedure ─────────────────────────────────────────────────
# ✅ Created in SOURCE project: sw-dev-prj-sandbox / pubsub_gcs_dataflow
# ── This is where the procedure lives — NOT in the destination project ────────
resource "google_bigquery_routine" "sp_clone_all_tables" {
  project      = "sw-dev-prj-sandbox"       # ✅ Source project
  dataset_id   = "pubsub_gcs_dataflow"      # ✅ Source dataset (procedure lives here)
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
    DECLARE query      STRING;

    -- Build query separately to avoid nested single-quote conflict
    SET query = CONCAT(
      'SELECT ARRAY_AGG(table_name) ',
      'FROM `', src_project, '.region-us-east4.INFORMATION_SCHEMA.TABLES` ',
      'WHERE table_schema = "', src_dataset, '" ',
      'AND table_type = "BASE TABLE"'
    );

    EXECUTE IMMEDIATE query INTO table_list;

    -- Guard: treat empty source dataset as empty array
    SET table_list = IFNULL(table_list, []);

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

# ── Invoke the stored procedure via a BigQuery Query Job ─────────────────────
resource "google_bigquery_job" "invoke_sp_clone_all_tables" {
  project  = "sw-dev-prj-sandbox"
  job_id   = "invoke-sp-clone-all-tables-v1"   # ✅ Fix 3: static ID, no timestamp drift
  location = "us-east4"

  query {
    # ✅ Fix 1: Single CALL statement — pass literal values directly, no DECLARE needed
    query = "CALL `sw-dev-prj-sandbox.pubsub_gcs_dataflow.sp_clone_all_tables`('sw-dev-prj-sandbox', 'pubsub_gcs_dataflow', 'sw-dev-prj-itp-secrets', 'copyjob_streaming_dataset');"

    use_legacy_sql = false
    # ✅ Fix 2: Removed create_disposition and write_disposition — invalid for procedure calls
  }

  depends_on = [google_bigquery_routine.sp_clone_all_tables]
}