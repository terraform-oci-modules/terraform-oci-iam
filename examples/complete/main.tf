provider "oci" {}

locals {
  name = "ex-complete"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-iam"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# Everything in one module call: two compartments, two groups (one accepts an
# optional member list via var.group_member_user_ids), two dynamic groups, and
# three policies (one tenancy-scoped, two compartment-scoped). The module's
# internal depends_on makes a single apply create compartments and groups before
# the policies that name them.
################################################################################

module "iam" {
  source = "../../"

  tenancy_id     = var.tenancy_id
  compartment_id = var.compartment_id

  tags = local.tags

  compartments = {
    (local.name) = {
      description = "Primary workload compartment"
      tags        = { Tier = "workload" }
    }
    "${local.name}-shared" = {
      description = "Shared services compartment"
    }
  }

  groups = {
    "${local.name}-platform-admins" = {
      description = "Platform administrators"
      user_ids    = var.group_member_user_ids
    }
    "${local.name}-readers" = {
      description = "Read-only auditors"
    }
  }

  dynamic_groups = {
    "${local.name}-instances" = {
      description   = "Compute instances in the primary compartment"
      matching_rule = "ALL {instance.compartment.id = '${coalesce(var.compartment_id, var.tenancy_id)}'}"
    }
    "${local.name}-functions" = {
      description   = "Functions in the primary compartment"
      matching_rule = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${coalesce(var.compartment_id, var.tenancy_id)}'}"
    }
  }

  policies = {
    "${local.name}-readers-tenancy" = {
      description    = "Read-only auditors may inspect the whole tenancy"
      compartment_id = var.tenancy_id
      version_date   = "2024-01-01"
      statements = [
        "Allow group ${local.name}-readers to read all-resources in tenancy",
      ]
    }
    "${local.name}-platform-admins" = {
      description = "Platform admins manage everything in the primary compartment"
      statements = [
        "Allow group ${local.name}-platform-admins to manage all-resources in compartment ${local.name}",
      ]
    }
    "${local.name}-workload-principals" = {
      description = "Workload principals in the primary compartment"
      statements = [
        "Allow dynamic-group ${local.name}-instances to read objectstorage-namespaces in compartment ${local.name}",
        "Allow dynamic-group ${local.name}-functions to use stream-pull in compartment ${local.name}",
      ]
    }
  }
}
