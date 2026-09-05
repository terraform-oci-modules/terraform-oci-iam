provider "oci" {}

locals {
  name = "ex-simple"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-iam"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# IAM module - one compartment, one group, one policy
################################################################################

module "iam" {
  source = "../../"

  tenancy_id     = var.tenancy_id
  compartment_id = var.compartment_id

  compartments = {
    (local.name) = {
      description = "Simple example compartment"
    }
  }

  groups = {
    "${local.name}-admins" = {
      description = "Administrators of the ${local.name} compartment"
    }
  }

  policies = {
    "${local.name}-admins" = {
      description = "Let ${local.name}-admins manage everything in the ${local.name} compartment"
      statements = [
        "Allow group ${local.name}-admins to manage all-resources in compartment ${local.name}",
      ]
    }
  }

  tags = local.tags
}
