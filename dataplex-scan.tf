
module "data_profile_scan" {
  for_each          = local.datascan_configs
  source            = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"
  project_id        = each.value.project_id
  name              = each.key
  region            = each.value.region
  data              = each.value.data
  data_profile_spec = each.value.data_profile_spec
}