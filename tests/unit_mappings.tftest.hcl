################################################################################
# Mock unit tests: fast, free, no real OCI resources.
#
# Exercises input->config mapping logic (scope defaulting, membership flattening
# and dedup, per-entry tag merging, tenancy pinning of groups/dynamic groups)
# against the module root with a mocked OCI provider (command = plan). Run on its
# own:
#   terraform test -filter=tests/unit_mappings.tftest.hcl
################################################################################

mock_provider "oci" {}

variables {
  tenancy_id     = "ocid1.tenancy.oc1..aaaaaaaaunittenancy"
  compartment_id = "ocid1.compartment.oc1..aaaaaaaaunitcompartment"
}

# --- Scope defaulting --------------------------------------------------------

run "policy_defaults_to_compartment_id" {
  command = plan

  variables {
    policies = {
      p1 = {
        description = "test"
        statements  = ["Allow group g1 to read all-resources in tenancy"]
      }
    }
  }

  assert {
    condition     = oci_identity_policy.this["p1"].compartment_id == "ocid1.compartment.oc1..aaaaaaaaunitcompartment"
    error_message = "a policy with no compartment_id must attach to var.compartment_id"
  }
}

run "policy_explicit_compartment_id_wins" {
  command = plan

  variables {
    policies = {
      p1 = {
        description    = "test"
        compartment_id = "ocid1.compartment.oc1..aaaaaaaaother"
        statements     = ["Allow group g1 to read all-resources in tenancy"]
      }
    }
  }

  assert {
    condition     = oci_identity_policy.this["p1"].compartment_id == "ocid1.compartment.oc1..aaaaaaaaother"
    error_message = "policies[*].compartment_id must override the default scope"
  }
}

run "compartment_defaults_parent_to_default_scope" {
  command = plan

  variables {
    compartments = {
      team-a = { description = "team a" }
    }
  }

  assert {
    condition     = oci_identity_compartment.this["team-a"].compartment_id == "ocid1.compartment.oc1..aaaaaaaaunitcompartment"
    error_message = "a compartment with no parent_id must be created under var.compartment_id"
  }
}

run "compartment_explicit_parent_wins" {
  command = plan

  variables {
    compartments = {
      team-a = { description = "team a", parent_id = "ocid1.compartment.oc1..aaaaaaaaparent" }
    }
  }

  assert {
    condition     = oci_identity_compartment.this["team-a"].compartment_id == "ocid1.compartment.oc1..aaaaaaaaparent"
    error_message = "compartments[*].parent_id must override the default parent"
  }
}

run "compartment_enable_delete_defaults_true" {
  command = plan

  variables {
    compartments = {
      team-a = { description = "team a" }
    }
  }

  assert {
    condition     = oci_identity_compartment.this["team-a"].enable_delete == true
    error_message = "enable_delete must default to true (module default, not the provider default of false)"
  }
}

# --- Tenancy pinning --------------------------------------------------------

run "groups_and_dynamic_groups_are_tenancy_scoped" {
  command = plan

  variables {
    compartment_id = "ocid1.compartment.oc1..aaaaaaaaunitcompartment"
    groups = {
      g1 = { description = "group one" }
    }
    dynamic_groups = {
      dg1 = { description = "dyn group one", matching_rule = "ALL {instance.compartment.id = 'x'}" }
    }
  }

  assert {
    condition     = oci_identity_group.this["g1"].compartment_id == "ocid1.tenancy.oc1..aaaaaaaaunittenancy"
    error_message = "groups must be created in the tenancy, never in var.compartment_id"
  }

  assert {
    condition     = oci_identity_dynamic_group.this["dg1"].compartment_id == "ocid1.tenancy.oc1..aaaaaaaaunittenancy"
    error_message = "dynamic groups must be created in the tenancy"
  }
}

# --- Group membership flattening + dedup ------------------------------------

run "memberships_flatten_across_groups" {
  command = plan

  variables {
    groups = {
      g1 = { description = "one", user_ids = ["ocid1.user.oc1..aaaaaaaaa", "ocid1.user.oc1..aaaaaaaab"] }
      g2 = { description = "two", user_ids = ["ocid1.user.oc1..aaaaaaaaa"] }
    }
  }

  assert {
    condition     = length(oci_identity_user_group_membership.this) == 3
    error_message = "3 memberships expected: g1 has 2 users, g2 has 1"
  }

  assert {
    condition     = contains(keys(oci_identity_user_group_membership.this), "g1/ocid1.user.oc1..aaaaaaaaa")
    error_message = "membership keys must be \"<group>/<user_ocid>\""
  }

  assert {
    condition     = oci_identity_user_group_membership.this["g2/ocid1.user.oc1..aaaaaaaaa"].user_id == "ocid1.user.oc1..aaaaaaaaa"
    error_message = "the same user OCID may belong to more than one group"
  }
}

run "duplicate_user_in_one_group_is_deduped" {
  command = plan

  variables {
    groups = {
      g1 = { description = "one", user_ids = ["ocid1.user.oc1..aaaaaaaaa", "ocid1.user.oc1..aaaaaaaaa"] }
    }
  }

  assert {
    condition     = length(oci_identity_user_group_membership.this) == 1
    error_message = "a user OCID listed twice in the same group must produce one membership, not a duplicate-key error"
  }
}

# --- Per-entry tag merge ---------------------------------------------------

run "entry_tags_merge_over_module_tags" {
  command = plan

  variables {
    tags = { Owner = "platform", Managed = "terraform" }
    groups = {
      g1 = { description = "one", tags = { Owner = "data", Extra = "yes" } }
    }
  }

  assert {
    condition     = oci_identity_group.this["g1"].freeform_tags["Owner"] == "data"
    error_message = "a per-entry tag must win over the module-wide tag of the same key"
  }

  assert {
    condition     = oci_identity_group.this["g1"].freeform_tags["Managed"] == "terraform"
    error_message = "module-wide tags must still apply to entries that do not override them"
  }

  assert {
    condition     = oci_identity_group.this["g1"].freeform_tags["Extra"] == "yes"
    error_message = "per-entry-only tags must be present"
  }
}

# --- create = false toggle -----------------------------------------------

run "create_false_makes_no_resources" {
  command = plan

  variables {
    create         = false
    compartments   = { c1 = { description = "c" } }
    groups         = { g1 = { description = "g" } }
    dynamic_groups = { d1 = { description = "d", matching_rule = "ALL {instance.id = 'x'}" } }
    policies       = { p1 = { description = "p", statements = ["Allow group g1 to read all-resources in tenancy"] } }
  }

  assert {
    condition     = length(oci_identity_compartment.this) == 0 && length(oci_identity_group.this) == 0 && length(oci_identity_dynamic_group.this) == 0 && length(oci_identity_policy.this) == 0
    error_message = "create = false must produce zero resources regardless of the input maps"
  }
}

# --- statement passthrough ----------------------------------------------

run "statements_pass_through_verbatim" {
  command = plan

  variables {
    policies = {
      p1 = {
        description = "verbatim"
        statements = [
          "Allow group admins to manage all-resources in compartment foo where request.region = 'us-ashburn-1'",
        ]
      }
    }
  }

  assert {
    condition     = oci_identity_policy.this["p1"].statements[0] == "Allow group admins to manage all-resources in compartment foo where request.region = 'us-ashburn-1'"
    error_message = "statement strings must reach the resource unchanged"
  }
}

################################################################################
# Negative paths: every validation block must have a reject case.
################################################################################

run "rejects_non_tenancy_ocid_for_tenancy_id" {
  command = plan

  variables {
    tenancy_id = "ocid1.compartment.oc1..aaaaaaaanotatenancy"
  }

  expect_failures = [var.tenancy_id]
}

run "rejects_bad_compartment_id" {
  command = plan

  variables {
    compartment_id = "not-an-ocid"
  }

  expect_failures = [var.compartment_id]
}

run "rejects_non_user_ocid_in_group_members" {
  command = plan

  variables {
    groups = {
      g1 = { description = "one", user_ids = ["ocid1.group.oc1..aaaaaaaawrongtype"] }
    }
  }

  expect_failures = [var.groups]
}

run "rejects_group_name_with_space" {
  command = plan

  variables {
    groups = {
      "bad name" = { description = "spaces are not allowed in OCI names" }
    }
  }

  expect_failures = [var.groups]
}

run "rejects_empty_matching_rule" {
  command = plan

  variables {
    dynamic_groups = {
      dg1 = { description = "one", matching_rule = "   " }
    }
  }

  expect_failures = [var.dynamic_groups]
}

run "rejects_policy_with_no_statements" {
  command = plan

  variables {
    policies = {
      p1 = { description = "one", statements = [] }
    }
  }

  expect_failures = [var.policies]
}

run "rejects_malformed_version_date" {
  command = plan

  variables {
    policies = {
      p1 = {
        description  = "one"
        statements   = ["Allow group g1 to read all-resources in tenancy"]
        version_date = "2024/01/01"
      }
    }
  }

  expect_failures = [var.policies]
}
