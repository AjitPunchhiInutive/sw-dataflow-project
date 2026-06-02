locals {

  # ── Step 1: load every YAML file from config/data-catalog-tags/ ──────────
  _catalog_tag_files = {
    for f in fileset("${path.module}/config/data-catalog-tags", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/data-catalog-tags/${f}")
    )
  }

  # ── Step 2: flatten all tags from every file into one merged map ──────────
  # Key format: "<file_key>/<tag_key>"  e.g. "pubsub-gcs-dataflow/historian-stream-messageid"
  catalog_tag_configs = merge([
    for file_key, file_val in local._catalog_tag_files :
    can(file_val.tags) ? {
      for tag_key, tag_val in file_val.tags :
      "${file_key}/${tag_key}" => {
        project_id = try(tag_val.project_id, file_val.project_id)
        parent     = tag_val.parent
        column     = try(tag_val.column, null)
        location   = try(tag_val.location, file_val.location)
        template   = tag_val.template
        fields     = tag_val.fields
      }
    } : {}
  ]...)
}

# ── Data Catalog Tags ────────────────────────────────────────────────────────
module "data_catalog_tag" {
  for_each   = local.catalog_tag_configs
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//data-catalog-tag?ref=main"

  project_id = each.value.project_id
  parent     = each.value.parent
  column     = each.value.column
  location   = each.value.location
  template   = each.value.template
  fields     = each.value.fields
}