locals {

  _catalog_tag_files = {
    for f in fileset("${path.module}/config/data-catalog-tags", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/data-catalog-tags/${f}")
    )
  }

  catalog_tag_configs = merge([
    for file_key, file_val in local._catalog_tag_files :
    can(file_val.tags) ? {
      for tag_key, tag_val in file_val.tags :
      "${file_key}/${tag_key}" => {
        project_id = file_val.project_id
        location   = file_val.location
        parent     = tag_val.parent
        column     = lookup(tag_val, "column", null)
        template   = tag_val.template
        fields     = tag_val.fields
      }
    } : {}
  ]...)
}

module "data_catalog_tag" {
  source = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//data-catalog-tag?ref=main"

  tags = {
    for k, v in local.catalog_tag_configs :
    k => {
      project_id = v.project_id
      location   = v.location
      parent     = v.parent
      column     = v.column
      template   = v.template
      fields     = v.fields
    }
  }
}