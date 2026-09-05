provider "oci" {}

locals {
  name = "ex-compartments"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-oci-iam"
    GithubOrg  = "terraform-oci-modules"
  }
}

################################################################################
# A three-level compartment hierarchy.
#
# parent_id takes a compartment OCID, so a hierarchy is built with one module
# call per level, each referencing the previous level's compartment_ids output.
#
#   ex-compartments                (level 1, under tenancy or compartment_id)
#   \- ex-compartments-prod        (level 2)
#      \- ex-compartments-prod-app (level 3)
#
# The upper levels raise timeouts.delete: compartment deletion is asynchronous
# and a parent has to wait for its children to finish deleting first.
#
# To keep a compartment out of Terraform's delete path, set enable_delete = false
# on it - but keep such compartments top-level (a non-deletable child blocks
# deletion of its parent).
################################################################################

module "root" {
  source = "../../"

  tenancy_id     = var.tenancy_id
  compartment_id = var.compartment_id

  compartments = {
    (local.name) = {
      description = "Top of the example hierarchy"
      timeouts    = { delete = "30m" }
    }
  }

  tags = local.tags
}

module "environments" {
  source = "../../"

  tenancy_id = var.tenancy_id

  compartments = {
    "${local.name}-prod" = {
      description = "Production environment"
      parent_id   = module.root.compartment_ids[local.name]
      timeouts    = { delete = "30m" }
    }
  }

  tags = local.tags
}

module "teams" {
  source = "../../"

  tenancy_id = var.tenancy_id

  compartments = {
    "${local.name}-prod-app" = {
      description = "Application team space inside production"
      parent_id   = module.environments.compartment_ids["${local.name}-prod"]
    }
  }

  tags = local.tags
}
