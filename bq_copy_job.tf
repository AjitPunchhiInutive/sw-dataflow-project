# locals {
#   copy_tables = toset([
#     "historian_stream",
#     "historian_stream_error",
#     "historian_stream_demo"
#   ])
# }

# resource "google_bigquery_job" "copy_tables" {
#   for_each = local.copy_tables

#   project  = var.log_project_id
#   job_id   = "copy_pubsub_gcs_dataflow_${each.key}"
#   location = "us-east4"

#   copy {
#     write_disposition  = "WRITE_TRUNCATE"
#     create_disposition = "CREATE_IF_NEEDED"

#     source_tables {
#       project_id = var.log_project_id
#       dataset_id = module.bigquery-dataset.dataset_id
#       table_id   = each.key
#     }

#     destination_table {
#       project_id = "sw-dev-prj-itp-secrets"
#       dataset_id = module.bigquery-dataset-copyjob.dataset_id
#       table_id   = each.key
#     }
#   }

#   depends_on = [
#     module.bigquery-dataset,
#     module.bigquery-dataset-copyjob
#   ]
# }