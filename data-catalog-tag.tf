locals {

  _catalog_tag_files = {
    for f in fileset("${path.module}/config/data-catalog-tags", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/data-catalog-tags/${f}")
    )
  }

  # Group tags by file so each module instance = one file (one project/location)
  catalog_tag_configs = {
    for file_key, file_val in local._catalog_tag_files :
    file_key => {
      project_id = file_val.project_id
      location   = file_val.location
      tags = {
        for tag_key, tag_val in file_val.tags :
        tag_key => {
          parent   = tag_val.parent
          column   = lookup(tag_val, "column", null)
          template = tag_val.template
          fields   = tag_val.fields
        }
      }
    }
    if can(file_val.tags)
  }
}

module "data_catalog_tag" {
  for_each   = local.catalog_tag_configs
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//data-catalog-tag?ref=main"

  project_id = each.value.project_id
  location   = each.value.location
  tags       = each.value.tags
}