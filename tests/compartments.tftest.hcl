# Real-apply test for examples/compartments.
# Requires OCI credentials and TF_VAR_tenancy_id.
# The oci provider must be configured for the tenancy home region.
#
# NOTE: compartment deletion is slow (minutes each, bottom-up). On delete OCI
# renames the compartment with a random suffix, freeing the original name for
# immediate reuse, so this test is re-runnable.

run "creates_compartment_hierarchy" {
  command = apply

  module {
    source = "./examples/compartments"
  }

  assert {
    condition     = output.root_compartment_id != null
    error_message = "Top-level compartment must be created"
  }
  assert {
    condition     = length(output.environment_compartment_ids) == 1
    error_message = "The level-2 prod compartment must be created"
  }
  assert {
    condition     = length(output.team_compartment_ids) == 1
    error_message = "The level-3 team compartment must be created"
  }
}
