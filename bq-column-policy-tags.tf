locals {

  # ── Build a flat lookup: "taxonomy_key/tag_key" → policy tag resource ID ──
  # module.policy_tag_taxonomy[key].tags returns:
  #   { public = { id = "projects/.../policyTags/123" }, confidential = { id = ... }, ... }
  policy_tag_id_map = merge([
    for taxonomy_key, taxonomy_mod in module.policy_tag_taxonomy : {
      for tag_key, tag_val in taxonomy_mod.tags :
      "${taxonomy_key}/${tag_key}" => tag_val.id
    }
  ]...)

  # ── Load all YAML files from config/bq-column-tags/ ───────────────────────
  _bq_column_tag_files = {
    for f in fileset("${path.module}/config/bq-column-tags", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/bq-column-tags/${f}")
    )
  }

  # ── Flatten all tables across every YAML file ─────────────────────────────
  bq_column_tag_configs = merge([
    for file_key, file_val in local._bq_column_tag_files :
    can(file_val.tables) ? {
      for table_key, table_val in file_val.tables :
      "${file_key}/${table_key}" => {
        project_id    = lookup(file_val, "log_project_id", var.log_project_id)
        dataset_id    = table_val.dataset_id
        table_id      = table_val.table_id
        taxonomy_key  = table_val.taxonomy_key   # must match a key in local.taxonomy_configs
        columns       = table_val.columns
      }
    } : {}
  ]...)
}

###############################################################################
# BigQuery Tables — schema with policyTags injected from taxonomy module output
###############################################################################

resource "google_bigquery_table" "tagged" {
  for_each = local.bq_column_tag_configs

  project             = each.value.log_project_id
  dataset_id          = each.value.dataset_id
  table_id            = each.value.table_id
  deletion_protection = false

  # Dynamically build schema JSON, injecting policyTags where policy_tag is set
  schema = jsonencode([
    for col in each.value.columns : merge(
      {
        name        = col.name
        type        = col.type
        mode        = lookup(col, "mode", "NULLABLE")
        description = lookup(col, "description", "")
      },
      # Only inject policyTags block when column has a policy_tag set
      lookup(col, "policy_tag", null) != null ? {
        policyTags = {
          names = [
            local.policy_tag_id_map["${each.value.taxonomy_key}/${col.policy_tag}"]
          ]
        }
      } : {}
    )
  ])

  depends_on = [module.policy_tag_taxonomy]
}
