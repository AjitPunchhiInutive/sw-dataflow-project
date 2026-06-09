# ###############################################################################
# # dataplex-datascan.tf  –  Data Quality Scans  (YAML-driven factory)
# ###############################################################################

# locals {

#   # ── Step 1: load all YAML files ──────────────────────────────────────────
#   _datascan_quality_raw = {
#     for f in fileset("${path.module}/config/dataplex-quality-scans", "*.yaml") :
#     trimsuffix(f, ".yaml") => yamldecode(
#       file("${path.module}/config/dataplex-quality-scans/${f}")
#     )
#   }

#   # ── Step 2: validate required keys ───────────────────────────────────────
#   _datascan_quality_validation = {
#     for key, val in local._datascan_quality_raw :
#     key => {
#       has_project_id = can(val.project_id)
#       has_region     = can(val.region)
#       has_scans      = can(val.scans)
#     }
#   }

#   # ── Step 3: flatten scans across all files ────────────────────────────────
#   datascan_quality_configs = merge([
#     for file_key, file_val in local._datascan_quality_raw :
#     can(file_val.scans) ? {
#       for scan_key, scan_val in file_val.scans :
#       scan_key => {
#         project_id         = lookup(file_val, "project_id", v.project_id)
#         region             = lookup(file_val, "region", var.region)
#         labels             = lookup(scan_val, "labels", {})
#         execution_schedule = lookup(scan_val, "execution_schedule", null)
#         data               = scan_val.data
#         incremental_field  = lookup(scan_val, "incremental_field", null)
#         data_quality_spec  = scan_val.data_quality_spec
#       }
#     } : {}
#   ]...)
# }

# # ── Data Quality Scans ────────────────────────────────────────────────────────
# module "dataplex_datascan_quality" {
#   for_each   = local.datascan_quality_configs
#   source     = "git@github.com:AjitPunchhiInutive/-sw-prod-udp-rds-infra-modules.git//dataplex-datascan?ref=main"

#   name               = each.key
#   project_id         = each.value.project_id
#   region             = each.value.region
#   labels             = each.value.labels
#   execution_schedule = each.value.execution_schedule
#   data               = each.value.data
#   incremental_field  = each.value.incremental_field
#   data_quality_spec  = each.value.data_quality_spec
# }
