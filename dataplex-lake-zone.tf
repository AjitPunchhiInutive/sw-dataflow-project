locals {

  # ── Load all YAML files from config/dataplex/ ───────────────────────────
  _dataplex_raw = {
    for f in fileset("${path.module}/config/dataplex", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/dataplex/${f}")
    )
  }

  # ── Guard: surface any file that is missing required keys ───────────────
  # If this validation fires, the named file has the wrong structure.
  _dataplex_validation = {
    for key, val in local._dataplex_raw :
    key => {
      has_project_id = can(val.project_id)
      has_region     = can(val.region)
      has_zones      = can(val.zones)
    }
  }

  # ── Final map — only files that have all required keys ──────────────────
  dataplex_configs = {
    for key, val in local._dataplex_raw :
    key => val
    if can(val.project_id) && can(val.region) && can(val.zones)
  }

}

# ── Debug output — remove after fixing ──────────────────────────────────────
output "dataplex_yaml_validation" {
  value = local._dataplex_validation
}

# ── Dataplex Lakes module ────────────────────────────────────────────────────
module "dataplex" {
  for_each = local.dataplex_configs

  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex?ref=main"
  name       = each.key
  prefix     = try(each.value.prefix, "dev")       # safe default if missing
  project_id = each.value.project_id
  region     = each.value.region
  zones      = each.value.zones
}