locals{
  # ── Dataplex Data Profile Scans ────────────────────────────────────
  datascan_configs = {
    for f in fileset("${path.module}/config/dataplex-datascan", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex-datascan/${f}"))
  }

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