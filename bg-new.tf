# ── Load YAML config ──────────────────────────────────────────────────────────
locals {
  copyjob_bq_datasets = {
    for b in yamldecode(file("${path.module}/config/bigquery-datasets/dataflow-copy.yaml")) :
    b.name != null ? b.name : "default_key" => b
  }
}
module "copyjob_bq_datasets" {
  source   = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//bigquery-dataset?ref=main"
  for_each = local.copyjob_bq_datasets

  project_id    = each.value.destination_project_id
  id            = each.value.destination_name
  friendly_name = each.value.destination_friendly_name
  description   = each.value.destination_description
  location      = each.value.ldestination_ocation

  options = {
    default_table_expiration_ms     = each.value.options.default_table_expiration_ms
    default_partition_expiration_ms = each.value.options.default_partition_expiration_ms
    delete_contents_on_destroy      = each.value.options.delete_contents_on_destroy
  }
}

resource "google_bigquery_routine" "sp_clone_all_tables_sw" {
  for_each = local.copyjob_bq_datasets

  project      = each.value.source.project
  dataset_id   = each.value.source.dataset
  routine_id   = each.value.source.routine
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

  depends_on = [module.copyjob_bq_datasets]
}

resource "google_bigquery_job" "invoke_sp_clone_all_tables_sw" {
  for_each = local.copyjob_bq_datasets

  project  = each.value.source.project
  job_id   = each.value.job.job_id
  location = each.value.source.location

  query {
    query = <<-EOT
      DECLARE src_project  STRING DEFAULT '${each.value.source.project}';
      DECLARE src_dataset  STRING DEFAULT '${each.value.source.dataset}';
      DECLARE dest_project STRING DEFAULT '${each.value.project_id}';
      DECLARE dest_dataset STRING DEFAULT '${each.value.name}';

      CALL `${each.value.source.project}.${each.value.source.dataset}.${each.value.source.routine}`(
        src_project,
        src_dataset,
        dest_project,
        dest_dataset
      );
    EOT

    use_legacy_sql     = each.value.job.use_legacy_sql
    create_disposition = ""
    write_disposition  = ""
  }

  depends_on = [google_bigquery_routine.sp_clone_all_tables_sw]
}

# ── 4. Scheduled Nightly Job ──────────────────────────────────────────────────
# ✅ Fix 2: each.value.* replaces local.src.* / local.schedule.*
resource "google_bigquery_data_transfer_config" "nightly_dev_reset_demo" {
  for_each = local.copyjob_bq_datasets

  project        = each.value.source.project
  location       = each.value.source.location
  display_name   = each.value.schedule.display_name
  data_source_id = "scheduled_query"
  schedule       = each.value.schedule.schedule

  schedule_options {
    start_time = timeadd(timestamp(), "24h")
  }

  params = {
    query = "CALL `${each.value.source.project}.${each.value.source.dataset}.${each.value.source.routine}`('${each.value.source.project}', '${each.value.source.dataset}', '${each.value.project_id}', '${each.value.name}');"
  }

  service_account_name = each.value.schedule.service_account

  depends_on = [google_bigquery_routine.sp_clone_all_tables_sw]
}