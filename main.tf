# locals {
#   sc_config_files = fileset("config/service-control", "*.yaml")
#   config          = yamldecode(file("config/service-control/${one(local.sc_config_files)}"))
# }
# module "VPC-SC" {
#   source          = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//VPC-SC?ref=main"
#   config          = local.config
# }
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

  # ── Dataplex Data Profile Scans ────────────────────────────────────
  datascan_configs = {
    for f in fileset("${path.module}/config/dataplex-datascan", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/config/dataplex-datascan/${f}"))
  }
}