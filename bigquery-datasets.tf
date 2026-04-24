# ── BigQuery Dataset ──────────────────────────────────────────────────────────
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

# ── BigQuery Routine (Stored Procedure) ───────────────────────────────────────
resource "google_bigquery_routine" "sp_clone_all_tables" {
  project      = "sw-dev-prj-itp-secrets"
  dataset_id   = module.bigquery-dataset-copyjob.dataset_id
  routine_id   = "sp_clone_all_tables"
  routine_type = "PROCEDURE"
  language     = "SQL"

  # ── Input arguments ──────────────────────────────────────────────────────────
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

  # ── Procedure body (BEGIN...END — no CREATE OR REPLACE header in body) ───────
  definition_body = <<-EOT
    DECLARE table_list ARRAY<STRING>;
    DECLARE i          INT64 DEFAULT 0;
    DECLARE table_name STRING;
    DECLARE query      STRING;

    -- ✅ Fix 1: Build query with CONCAT to avoid 'BASE TABLE' nested quote issue
    SET query = CONCAT(
      'SELECT ARRAY_AGG(table_name) ',
      'FROM `', src_project, '.region-us-east4.INFORMATION_SCHEMA.TABLES` ',
      'WHERE table_schema = "', src_dataset, '" ',
      'AND table_type = "BASE TABLE"'
    );

    EXECUTE IMMEDIATE query INTO table_list;

    -- ✅ Fix 2: Guard against NULL when source dataset has no tables
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