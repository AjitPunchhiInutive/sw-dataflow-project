# locals {
#   sc_config_files = fileset("config/service-control", "*.yaml")
#   config          = yamldecode(file("config/service-control/${one(local.sc_config_files)}"))
# }
# module "VPC-SC" {
#   source          = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//VPC-SC?ref=main"
#   config          = local.config
# }
locals {
  dataplex_configs = {
    for b in flatten([for f in fileset("${path.module}/config/dataplex", "*.yaml") : yamldecode(file("${path.module}/config/dataplex/${f}"))]) : b.name => b
  }
}
locals {
  datascan_configs = {
    for b in flatten([
      for f in fileset("${path.module}/config/dataplex-datascan", "*.yaml") :
      yamldecode(file("${path.module}/config/dataplex-datascan/${f}"))
    ]) : b.name => b
  }
}
