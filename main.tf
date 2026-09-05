locals {
  create = var.create

  # Policies and compartments default to this scope; groups and dynamic groups
  # are always tenancy-scoped (an OCI constraint).
  default_compartment_id = coalesce(var.compartment_id, var.tenancy_id)

  # Flatten groups[*].user_ids into one membership map keyed by "<group>/<user_ocid>".
  # distinct() guards against a user OCID listed twice in the same group.
  group_memberships = merge([
    for group_name, group in var.groups : {
      for user_id in distinct(group.user_ids) :
      "${group_name}/${user_id}" => {
        group_name = group_name
        user_id    = user_id
      }
    }
  ]...)
}

################################################################################
# Compartments
################################################################################

resource "oci_identity_compartment" "this" {
  for_each = local.create ? var.compartments : {}

  compartment_id = coalesce(each.value.parent_id, local.default_compartment_id)
  name           = each.key
  description    = each.value.description
  enable_delete  = each.value.enable_delete

  freeform_tags = merge(var.tags, each.value.tags)
  defined_tags  = merge(var.defined_tags, each.value.defined_tags)

  dynamic "timeouts" {
    for_each = each.value.timeouts != null ? [each.value.timeouts] : []
    content {
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    # OCI auto-injects Oracle-Tags (CreatedBy/CreatedOn) into defined_tags and can
    # apply compartment tag defaults; ignoring both tag maps avoids perpetual
    # drift. Matches terraform-oci-vcn / terraform-oci-oke. Trade-off: tag changes
    # after create are not reconciled by this module.
    ignore_changes = [defined_tags, freeform_tags]
  }
}

################################################################################
# Groups  (always tenancy-scoped)
################################################################################

resource "oci_identity_group" "this" {
  for_each = local.create ? var.groups : {}

  compartment_id = var.tenancy_id
  name           = each.key
  description    = each.value.description

  freeform_tags = merge(var.tags, each.value.tags)
  defined_tags  = merge(var.defined_tags, each.value.defined_tags)

  lifecycle {
    # OCI auto-injects Oracle-Tags (CreatedBy/CreatedOn) into defined_tags and can
    # apply compartment tag defaults; ignoring both tag maps avoids perpetual
    # drift. Matches terraform-oci-vcn / terraform-oci-oke. Trade-off: tag changes
    # after create are not reconciled by this module.
    ignore_changes = [defined_tags, freeform_tags]
  }
}

################################################################################
# Group memberships  (maps to aws_iam_group_membership)
################################################################################

resource "oci_identity_user_group_membership" "this" {
  for_each = local.create ? local.group_memberships : {}

  group_id = oci_identity_group.this[each.value.group_name].id
  user_id  = each.value.user_id
}
