locals {

  # ── Step 1: load every YAML file ────────────────────────────────────────
  _datascan_files = {
    for f in fileset("${path.module}/config/dataplex-datascan", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/dataplex-datascan/${f}")
    )
  }

  # ── Step 2: flatten scans map from every file ────────────────────────────
  # Merges all `scans:` blocks across all YAML files into one flat map.
  # Each scan inherits project_id and region from its parent file.
  # Result: { "ot-telemetry-profile" => { project_id, region, data, data_profile_spec } }
  datascan_configs = merge([
    for file_key, file_val in local._datascan_files : {
      for scan_key, scan_val in file_val.scans :
      scan_key => {
        project_id        = file_val.project_id
        region            = file_val.region
        data              = scan_val.data
        data_profile_spec = scan_val.data_profile_spec
      }
    }
  ]...)

}

# ── Debug output — remove after validating ───────────────────────────────────
output "datascan_configs_debug" {
  value = {
    for k, v in local.datascan_configs :
    k => {
      project_id = v.project_id
      region     = v.region
      resource   = v.data.resource
    }
  }
}

# ── Data Profile Scans ────────────────────────────────────────────────────────

module "data_profile_scan" {
  for_each          = local.datascan_configs
  source            = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"
  project_id        = each.value.project_id
  name              = each.key
  region            = each.value.region
  data              = each.value.data
  data_profile_spec = each.value.data_profile_spec
}