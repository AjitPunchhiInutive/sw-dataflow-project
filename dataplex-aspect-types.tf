locals {

  # ── Dataplex Aspect Types ─────────────────────────────────────────────────
  _aspect_types_raw = {
    for f in fileset("${path.module}/config/dataplex-aspect-types", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/dataplex-aspect-types/${f}")
    )
  }

  _aspect_types_validation = {
    for key, val in local._aspect_types_raw :
    key => {
      has_display_name      = can(val.display_name)
      has_description       = can(val.description)
      has_metadata_template = can(val.metadata_template)
    }
  }

  # Build the aspect_types map expected by the module:
  # { "manufacturing" => { display_name, description, labels, metadata_template } }
  aspect_types_configs = {
    for key, val in local._aspect_types_raw :
    key => {
      display_name      = val.display_name
      description       = try(val.description, "")
      labels            = try(val.labels, {})
      metadata_template = val.metadata_template
    }
    if can(val.display_name) && can(val.metadata_template)
  }

}

# ── Debug output — remove after validating ───────────────────────────────────
output "aspect_types_yaml_validation" {
  value = local._aspect_types_validation
}

# ── Dataplex Aspect Types ─────────────────────────────────────────────────────
# No for_each — one module call passes the full map via the aspect_types variable.
# The module iterates internally over the map to create each aspect type.

module "dataplex_aspect_types" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-aspect-types?ref=main"
  project_id = "sw-dev-prj-sandbox"
  location   = "us-east4"

  aspect_types = local.aspect_types_configs
}