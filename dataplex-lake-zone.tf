locals {
  dataplex_configs = {
    for b in flatten([for f in fileset("${path.module}/config/dataplex", "*.yaml") : yamldecode(file("${path.module}/config/dataplex/${f}"))]) : b.name => b
  }
}
module "dataplex" {
  for_each   = local.dataplex_configs
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex?ref=main"
  name       = each.key                  # "manufacturing"
  prefix     = each.value.prefix         # "dev"
  project_id = each.value.project_id     # "sw-dev-prj-sandbox"
  region     = each.value.region         # "us-east4"
  zones      = each.value.zones
}