# locals {
#   aspect_types_configs = {
#     for f in fileset("${path.module}/config/dataplex/aspect-types", "*.yaml") :
#     trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex/aspect-types/${f}"))
#   }

#   # Read project_id and location from the first file (all files should share the same values)
#   _aspect_meta = values(local.aspect_types_configs)[0]
# }

# module "dataplex_aspect_types" {
#   source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-aspect-types?ref=main"
#   project_id = local._aspect_meta.project_id
#   location   = local._aspect_meta.location

#   aspect_types = {
#     for key, val in local.aspect_types_configs : key => {
#       display_name      = val.display_name
#       description       = try(val.description, "")
#       labels            = try(val.labels, {})
#       metadata_template = val.metadata_template
#     }
#   }
# }