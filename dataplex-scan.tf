module "data_profile_scan" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"
  project_id = "sw-dev-prj-sandbox"
  name       = "customer-orders-profile"
  region     = "us-east4"
  data = {
    resource = "//bigquery.googleapis.com/projects/sw-dev-prj-sandbox/datasets/pubsub_gcs_dataflow/tables/historian_stream"
  }
  # execution_schedule = "TZ=UTC 0 2 * * *"
  credential_type           = "SERVICE_ACCOUNT"
  execution_service_account = "dataplex-scanner@sw-dev-prj-sandbox.iam.gserviceaccount.com"
  data_profile_spec = {
    sampling_percent = 20
    row_filter       = null   # null = scan all rows
    include_fields   = null   # null = all columns
    exclude_fields   = null   # null = no exclusions
    post_scan_actions = {
      publish_to_bigquery = true
      bigquery_export = {
        results_table = "//bigquery.googleapis.com/projects/sw-dev-prj-sandbox/datasets/dataplex_profile_results/tables/customer_orders_profile"
      }
    }
  }
}