# Real-apply test for examples/simple.
# Requires OCI credentials, TF_VAR_tenancy_id, and (optionally) TF_VAR_compartment_id.
# The oci provider must be configured for the tenancy home region.

run "creates_simple_iam" {
  command = apply

  module {
    source = "./examples/simple"
  }

  assert {
    condition     = output.compartment_id != null
    error_message = "Compartment must be created"
  }
  assert {
    condition     = output.group_id != null
    error_message = "Group must be created"
  }
  assert {
    condition     = output.policy_id != null
    error_message = "Policy must be created"
  }
  assert {
    condition     = length(output.policy_statements) == 1
    error_message = "Policy must carry exactly the one configured statement"
  }
}
