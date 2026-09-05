################################################################################
# Dynamic Groups  (always tenancy-scoped)
#
# The OCI expression of workload identity. A dynamic group is a rule that matches
# principals (instances, functions, OKE workloads, ...); a policy then grants the
# dynamic group. Nothing is attached to the workload itself.
################################################################################

resource "oci_identity_dynamic_group" "this" {
  for_each = local.create ? var.dynamic_groups : {}

  compartment_id = var.tenancy_id
  name           = each.key
  description    = each.value.description
  matching_rule  = each.value.matching_rule

  freeform_tags = merge(var.tags, each.value.tags)
  defined_tags  = merge(var.defined_tags, each.value.defined_tags)

  lifecycle {
    # See the note in main.tf: OCI auto-injects Oracle-Tags, so both tag maps are
    # ignored after create to avoid perpetual drift.
    ignore_changes = [defined_tags, freeform_tags]
  }
}
