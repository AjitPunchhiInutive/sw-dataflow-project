locals {

  # ── Step 1: load every YAML file ──────────────────────────────────────
  _datascan_files = {
    for f in fileset("${path.module}/config/dataplex", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/dataplex/${f}")
    )
  }

  # ── Step 2: flatten multi-scan files (new format) ─────────────────────
  # NEW format — file has a `scans:` block
  _multi_scan_configs = merge([
    for file_key, file_val in local._datascan_files :
    can(file_val.scans) ? {
      for scan_key, scan_val in file_val.scans :
      scan_key => {
        project_id        = file_val.project_id
        region            = file_val.region
        data              = scan_val.data
        data_profile_spec = scan_val.data_profile_spec
      }
    } : {}
  ]...)

  # ── Step 3: wrap single-scan files (old format) ────────────────────────
  # OLD format — file has `data:` and `data_profile_spec:` directly
  _single_scan_configs = {
    for file_key, file_val in local._datascan_files :
    file_key => {                          # ← plain object, no ternary needed
      project_id        = file_val.project_id
      region            = file_val.region
      data              = file_val.data
      data_profile_spec = file_val.data_profile_spec
    }
    if !can(file_val.scans) && can(file_val.data)  # only old-format files
  }

  # ── Step 4: merge both into one final map ─────────────────────────────
  datascan_configs = merge(
    local._single_scan_configs,
    local._multi_scan_configs
  )

}

# ── Data Profile Scans ─────────────────────────────────────────────────────
module "data_profile_scan" {
  for_each          = local.datascan_configs
  source            = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"
  project_id        = each.value.project_id
  name              = each.key
  region            = each.value.region
  data              = each.value.data
  data_profile_spec = each.value.data_profile_spec
}