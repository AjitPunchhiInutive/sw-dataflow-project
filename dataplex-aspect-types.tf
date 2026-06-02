locals {
  aspect_types_configs = {
    for f in fileset("${path.module}/config/dataplex/aspect-types", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex/aspect-types/${f}"))
  }
}

module "dataplex_aspect_types" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-aspect-types?ref=main"
  project_id = "sw-dev-prj-sandbox"
  location   = "us-east4"

  aspect_types = {
    for key, val in local.aspect_types_configs : key => {
      display_name      = val.display_name
      description       = try(val.description, "")
      labels            = try(val.labels, {})
      metadata_template = val.metadata_template
    }
  }
}