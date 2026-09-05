provider "oci" {}

locals {
  name = "ex-dyn-groups"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-iam"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# Two dynamic groups - one matching compute instances, one matching functions -
# each granted just what that workload class needs.
################################################################################

module "iam" {
  source = "../../"

  tenancy_id     = var.tenancy_id
  compartment_id = var.compartment_id

  dynamic_groups = {
    "${local.name}-instances" = {
      description   = "All compute instances in the example compartment"
      matching_rule = "ALL {instance.compartment.id = '${var.compartment_id}'}"
    }

    "${local.name}-functions" = {
      description   = "All functions in the example compartment"
      matching_rule = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_id}'}"
    }
  }

  policies = {
    "${local.name}-instances" = {
      description    = "Instance principals may read Object Storage buckets in their compartment"
      compartment_id = var.compartment_id
      statements = [
        "Allow dynamic-group ${local.name}-instances to read buckets in compartment id ${var.compartment_id}",
        "Allow dynamic-group ${local.name}-instances to read objects in compartment id ${var.compartment_id}",
      ]
    }

    "${local.name}-functions" = {
      description    = "Function principals may use streams and read secrets in their compartment"
      compartment_id = var.compartment_id
      statements = [
        "Allow dynamic-group ${local.name}-functions to use stream-pull in compartment id ${var.compartment_id}",
        "Allow dynamic-group ${local.name}-functions to read secret-family in compartment id ${var.compartment_id}",
      ]
    }
  }

  tags = local.tags
}
