# Real-apply test for examples/complete.
# Requires OCI credentials, TF_VAR_tenancy_id, and (optionally) TF_VAR_compartment_id.
# The oci provider must be configured for the tenancy home region.

run "creates_complete_iam" {
  command = apply

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = length(output.compartment_ids) == 2
    error_message = "Both compartments must be created"
  }
  assert {
    condition     = length(output.group_ids) == 2
    error_message = "Both groups must be created"
  }
  assert {
    condition     = length(output.dynamic_group_ids) == 2
    error_message = "Both dynamic groups must be created"
  }
  assert {
    condition     = length(output.policy_ids) == 3
    error_message = "All three policies must be created"
  }
  assert {
    condition     = alltrue([for _, v in output.group_memberships : length(v) == 0])
    error_message = "No members are configured by default; memberships must be empty"
  }
}
