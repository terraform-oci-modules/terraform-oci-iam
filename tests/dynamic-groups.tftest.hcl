# Real-apply test for examples/dynamic-groups.
# Requires OCI credentials, TF_VAR_tenancy_id, and TF_VAR_compartment_id.
# The oci provider must be configured for the tenancy home region.

run "creates_dynamic_groups_and_policies" {
  command = apply

  module {
    source = "./examples/dynamic-groups"
  }

  assert {
    condition     = length(output.dynamic_group_ids) == 2
    error_message = "Both dynamic groups must be created"
  }
  assert {
    condition     = length(output.policy_ids) == 2
    error_message = "Both policies must be created"
  }
  assert {
    condition     = can(regex("^ALL \\{instance\\.compartment\\.id", output.instance_matching_rule))
    error_message = "The instance dynamic group's matching rule must be stored as configured"
  }
}
