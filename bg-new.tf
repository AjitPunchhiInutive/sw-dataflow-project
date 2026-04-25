locals {
  cfg      = yamldecode(file("${path.module}/service-control/config.yaml")).bigquery
  src      = local.cfg.source
  dest     = local.cfg.destination
  job      = local.cfg.job
  schedule = local.cfg.schedule
  opts     = local.cfg.options
}

module "bigquery-dataset-demo" {
  source = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//bigquery-dataset?ref=main"

  project_id    = local.dest.project
  id            = local.dest.dataset
  friendly_name = local.dest.friendly_name
  description   = local.dest.description
  location      = local.dest.location

  options = {
    default_table_expiration_ms     = local.opts.default_table_expiration_ms
    default_partition_expiration_ms = local.opts.default_partition_expiration_ms
    delete_contents_on_destroy      = local.opts.delete_contents_on_destroy
  }
}

resource "google_bigquery_routine" "sp_clone_all_tables" {
  project      = local.src.project
  dataset_id   = local.src.dataset
  routine_id   = local.src.routine
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

    SET query = CONCAT(
      'SELECT ARRAY_AGG(table_name) ',
      'FROM `', src_project, '.region-us-east4.INFORMATION_SCHEMA.TABLES` ',
      'WHERE table_schema = "', src_dataset, '" ',
      'AND table_type = "BASE TABLE"'
    );

    EXECUTE IMMEDIATE query INTO table_list;

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

# ── 3. One-time Invocation Job ────────────────────────────────────────────────
resource "google_bigquery_job" "invoke_sp_clone_all_tables" {
  project  = local.src.project
  job_id   = local.job.job_id
  location = local.src.location

  query {
    query          = "CALL `${local.src.project}.${local.src.dataset}.${local.src.routine}`('${local.src.project}', '${local.src.dataset}', '${local.dest.project}', '${local.dest.dataset}');"
    use_legacy_sql = local.job.use_legacy_sql
  }

  depends_on = [google_bigquery_routine.sp_clone_all_tables]
}

# ── 4. Scheduled Nightly Job ──────────────────────────────────────────────────
resource "google_bigquery_data_transfer_config" "nightly_dev_reset" {
  project        = local.src.project
  location       = local.src.location
  display_name   = local.schedule.display_name
  data_source_id = "scheduled_query"
  schedule       = local.schedule.schedule

  schedule_options {
    start_time = timeadd(timestamp(), "24h")
  }

  params = {
    query = "CALL `${local.src.project}.${local.src.dataset}.${local.src.routine}`('${local.src.project}', '${local.src.dataset}', '${local.dest.project}', '${local.dest.dataset}');"
  }

  service_account_name = local.schedule.service_account

  depends_on = [google_bigquery_routine.sp_clone_all_tables]
}