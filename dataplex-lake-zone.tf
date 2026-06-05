locals {
  _dataplex_raw = {
    for f in fileset("${path.module}/config/dataplex", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex/${f}"))
  }
 
  _dataplex_validation = {
    for key, val in local._dataplex_raw :
    key => {
      has_project_id = can(val.project_id)
      has_region     = can(val.region)
      has_zones      = can(val.zones)
    }
  }
 
  dataplex_configs = {
    for key, val in local._dataplex_raw :
    key => val
    if can(val.project_id) && can(val.region) && can(val.zones)
  }
 
  # ── Rewrite zones: build full resource_name path per asset ───────────────
  # For same-project assets:  "projects/<lake_project>/datasets/<name>"
  # For cross-project assets: "projects/<resource_project_id>/datasets/<name>"
  dataplex_configs_resolved = {
  for lake_key, lake_val in local.dataplex_configs :
  lake_key => merge(lake_val, {
    zones = {
      for zone_key, zone_val in lake_val.zones :
      zone_key => merge(zone_val, {
        assets = {
          for asset_key, asset_val in zone_val.assets :
          asset_key => merge(asset_val, {
            resource_name = (
              asset_val.resource_spec_type == "BIGQUERY_DATASET"
              ? "projects/${lookup(asset_val, "resource_project_id", lake_val.project_id)}/datasets/${asset_val.resource_name}"
              : asset_val.resource_name
            )
          })
        }
      })
    }
  })
}
}
 
# ── Dataplex Lakes module ─────────────────────────────────────────────────────
module "dataplex" {
  for_each = local.dataplex_configs_resolved
 
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex?ref=main"
  name       = each.key
  prefix     = try(each.value.prefix, "dev")
  project_id = each.value.project_id
  region     = each.value.region
  zones      = each.value.zones
}