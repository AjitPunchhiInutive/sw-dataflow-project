module "data_profile_scan" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"
  project_id = var.log_project_id
  name       = var.scan_name
  region     = var.region

  data = {
    resource = "//bigquery.googleapis.com/projects/${var.bq_source_project}/datasets/${var.bq_source_dataset}/tables/${var.bq_source_table}"
  }

  execution_schedule = var.execution_schedule
  data_profile_spec = {
    sampling_percent = var.sampling_percent
    row_filter       = var.row_filter

    include_fields = length(var.include_fields) > 0 ? {
      field_names = var.include_fields
    } : null

    exclude_fields = length(var.exclude_fields) > 0 ? {
      field_names = var.exclude_fields
    } : null

    post_scan_actions = {
      bigquery_export = {
        results_table = "//bigquery.googleapis.com/projects/${var.project_id}/datasets/${var.results_dataset_id}/tables/${var.results_table_id}"
      }
    }
  }

  labels = var.labels
}