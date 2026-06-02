locals {
  _yaml_files = {
    for f in fileset("${path.module}/config/dataplex", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex/${f}"))
  }

  datascan_configs = merge(
    # Old format — data: and data_profile_spec: at root level
    {
      for k, v in local._yaml_files : k => {
        project_id        = v.project_id
        region            = v.region
        data              = v.data
        data_profile_spec = v.data_profile_spec
      } if !can(v.scans) && can(v.data)
    },
    # New format — scans: block with multiple scans
    merge([
      for k, v in local._yaml_files : can(v.scans) ? {
        for scan_key, scan_val in v.scans : scan_key => {
          project_id        = v.project_id
          region            = v.region
          data              = scan_val.data
          data_profile_spec = scan_val.data_profile_spec
        }
      } : {}
    ]...)
  )
}

module "data_profile_scan" {
  for_each          = local.datascan_configs
  source            = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"
  project_id        = each.value.project_id
  name              = each.key
  region            = each.value.region
  data              = each.value.data
  data_profile_spec = each.value.data_profile_spec
}