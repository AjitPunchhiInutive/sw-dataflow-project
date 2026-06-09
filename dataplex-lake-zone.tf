locals {
  _dataplex_raw = {
    for f in fileset("${path.module}/config/dataplex-lakes-zones", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex-lakes-zones/${f}"))
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

  dataplex_configs_resolved = {
    for lake_key, lake_val in local.dataplex_configs :
    lake_key => merge(lake_val, {
      zones = {
        for zone_key, zone_val in lake_val.zones :
        zone_key => merge(zone_val, {
          assets = {
            for asset_key, asset_val in zone_val.assets :
            asset_key => merge(asset_val, {
              resource_project = try(asset_val.resource_project, lake_val.project_id)
            })
          }
        })
      }
    })
  }
}

module "dataplex" {
  for_each = local.dataplex_configs_resolved

  source       = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex?ref=main"
  name         = each.value.name
  display_name = try(each.value.display_name, null)
  description  = try(each.value.description, null)
  prefix       = null
  project_id   = each.value.project_id
  region       = each.value.region
  zones        = each.value.zones
}