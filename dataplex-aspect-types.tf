locals {

 # ── Dataplex Aspect Types ────────────────────────────────────────────────
  _aspect_types_raw = {
    for f in fileset("${path.module}/config/dataplex-aspect-types", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/dataplex-aspect-types/${f}")
    )
  }

  _aspect_types_validation = {
    for key, val in local._aspect_types_raw :
    key => {
      has_display_name       = can(val.display_name)
      has_description        = can(val.description)
      has_metadata_template  = can(val.metadata_template)
    }
  }

  aspect_types_configs = {
    for key, val in local._aspect_types_raw :
    key => val
    if can(val.display_name) && can(val.metadata_template)
  }

}


module "dataplex_aspect_types" {
  for_each = local.aspect_types_configs

  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-aspect-types?ref=main"
  project_id = "sw-dev-prj-sandbox"
  location   = "us-east4"

  aspect_type_id    = each.key                                    # "manufacturing"
  display_name      = each.value.display_name                     # "Manufacturing"
  description       = try(each.value.description, "")
  labels            = try(each.value.labels, {})
  metadata_template = each.value.metadata_template
}