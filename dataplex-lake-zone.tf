locals {

  # ── Dataplex Lakes ─────────────────────────────────────────────────
  # Each YAML = one lake config (single map, not a list)
  # Use filename (minus .yaml) as the map key — no .name lookup needed
  dataplex_configs = {
    for f in fileset("${path.module}/config/dataplex", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/dataplex/${f}")
    )
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