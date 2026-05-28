module "dataplex_aspect_types" {
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-aspect-types?ref=main"
  project_id = "sw-dev-prj-sandbox"
  location   = "us-east4"

  factories_config = {
    aspect_types = "${path.module}/config/dataplex-aspect-types"
  }
}