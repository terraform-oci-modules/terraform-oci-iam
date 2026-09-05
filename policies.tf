################################################################################
# Policies  (maps to the iam-policy submodule)
#
# An OCI policy is not attached to a principal. It is a named object on a
# compartment (or the tenancy) holding statements in the form:
#   Allow <subject> to <verb> <resource-type> in <scope> [where <condition>]
# Statements are passed through verbatim.
################################################################################

resource "oci_identity_policy" "this" {
  for_each = local.create ? var.policies : {}

  compartment_id = coalesce(each.value.compartment_id, local.default_compartment_id)
  name           = each.key
  description    = each.value.description
  statements     = each.value.statements
  version_date   = each.value.version_date

  freeform_tags = merge(var.tags, each.value.tags)
  defined_tags  = merge(var.defined_tags, each.value.defined_tags)

  # A policy statement is validated by OCI against existing groups, dynamic
  # groups and compartments at create time. Force those to be created first so a
  # single apply that defines all four in one module call succeeds.
  depends_on = [
    oci_identity_group.this,
    oci_identity_dynamic_group.this,
    oci_identity_compartment.this,
  ]

  lifecycle {
    # See the note in main.tf: OCI auto-injects Oracle-Tags, so both tag maps are
    # ignored after create to avoid perpetual drift.
    ignore_changes = [defined_tags, freeform_tags]
  }
}
