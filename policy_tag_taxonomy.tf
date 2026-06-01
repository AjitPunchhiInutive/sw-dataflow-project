###############################################################################
# main.tf  –  Policy Tag Taxonomy  (YAML-driven factory pattern)
###############################################################################

locals {

  # ── Step 1: load every YAML file under config/policy-tags/ ──────────────
  _policy_tag_files = {
    for f in fileset("${path.module}/config/policy-tags", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(
      file("${path.module}/config/policy-tags/${f}")
    )
  }

  # ── Step 2: flatten multi-taxonomy files (new format) ──────────────────
  # NEW format — file has a `taxonomies:` block
  _multi_taxonomy_configs = merge([
    for file_key, file_val in local._policy_tag_files :
    can(file_val.taxonomies) ? {
      for tax_key, tax_val in file_val.taxonomies :
      tax_key => {
        project_id           = file_val.project_id
        location             = file_val.location
        name                 = tax_val.name
        tags                 = tax_val.tags
      }
    } : {}
  ]...)

  # ── Step 3: wrap single-taxonomy files (old format) ────────────────────
  # OLD format — file has `name:` and `tags:` directly (no `taxonomies:` block)
  _single_taxonomy_configs = {
    for file_key, file_val in local._policy_tag_files :
    file_key => {
      project_id            = file_val.project_id
      location              = file_val.location
      name                  = file_val.name
      tags                  = file_val.tags
    }
    if !can(file_val.taxonomies) && can(file_val.tags)
  }

  # ── Step 4: merge both into one final map ────────────────────────────────
  taxonomy_configs = merge(
    local._single_taxonomy_configs,
    local._multi_taxonomy_configs
  )
}

# ── Policy Tag Taxonomies ──────────────────────────────────────────────────
module "policy_tag_taxonomy" {
  for_each   = local.taxonomy_configs
  source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//data-catalog-policy-tag?ref=main"

  name       = each.value.name
  project_id = each.value.project_id
  location   = each.value.location
  tags       = each.value.tags

}
