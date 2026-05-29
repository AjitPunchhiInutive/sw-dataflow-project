locals {

  # ── Step 1: load every YAML file ────────────────────────────────────────
  _datascan_files = {
    for f in fileset("${path.module}/config/dataplex", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/dataplex/${f}")
    )
  }

  # ── Step 2: flatten — handle both old (single-scan) and new (multi-scan) ─
  #
  # OLD format (no `scans:` key) — customer-orders-profile.yaml:
  #   project_id: ...
  #   data: { resource: ... }
  #   data_profile_spec: { ... }
  #
  # NEW format (has `scans:` key) — manufacturing-scans.yaml:
  #   project_id: ...
  #   scans:
  #     scan-name-1: { data: ..., data_profile_spec: ... }
  #     scan-name-2: { data: ..., data_profile_spec: ... }
  # ─────────────────────────────────────────────────────────────────────────
  datascan_configs = merge([
    for file_key, file_val in local._datascan_files :

    # NEW multi-scan format — file has a `scans:` block
    can(file_val.scans) ? {
      for scan_key, scan_val in file_val.scans :
      scan_key => {
        project_id        = file_val.project_id
        region            = file_val.region
        data              = scan_val.data
        data_profile_spec = scan_val.data_profile_spec
      }
    } :

    # OLD single-scan format — file has `data:` and `data_profile_spec:` directly
    can(file_val.data) ? {
      file_key => {
        project_id        = file_val.project_id
        region            = file_val.region
        data              = file_val.data
        data_profile_spec = file_val.data_profile_spec
      }
    } :

    # Skip any file that matches neither format
    {}

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