locals {
  dataplex_configs = {
    for f in fileset("${path.module}/config/dataplex", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex/${f}"))
  }
}

module "dataplex" {
  for_each = local.dataplex_configs

  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex?ref=main"
  name       = each.key
  prefix     = try(each.value.prefix)
  project_id = each.value.project_id
  region     = each.value.region
  zones      = each.value.zones
}