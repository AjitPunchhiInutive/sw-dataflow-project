module "data_profile_scan" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"
  project_id = sw-dev-prj-sandbox
  name       = customer-orders-profile
  region     = us-east4

  data = {
    resource = "//bigquery.googleapis.com/projects/sw-dev-prj-sandbox/datasets/pubsub_gcs_dataflow/tables/historian_stream."
  }

  #execution_schedule = var.execution_schedule
  data_profile_spec = {
    sampling_percent = 20
    row_filter        = null
    include_fields    = null
    exclude_fields    = null
    post_scan_actions = null

    post_scan_actions = {
      bigquery_export = {
        results_table = "//bigquery.googleapis.com/projects/sw-dev-prj-sandbox/datasets/dataplex_profile_results/tables/customer_orders_profile"
      }
    }
  }
}