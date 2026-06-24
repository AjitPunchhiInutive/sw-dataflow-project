# locals {
#   sc_config_files = fileset("config/service-control", "*.yaml")
#   config          = yamldecode(file("config/service-control/${one(local.sc_config_files)}"))
# }
# module "VPC-SC" {
#   source          = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//VPC-SC?ref=main"
#   config          = local.config
# }
