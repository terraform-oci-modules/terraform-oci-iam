# Testing

The test suite lives in `tests/` - one `.tftest.hcl` file per example, plus a
credential-less mock suite. All tests run from the module root via a single
`terraform test` invocation.

## Prerequisites

- Terraform >= 1.7
- OCI credentials configured - any of:
  - Environment variables (`OCI_CLI_TENANCY`, `OCI_CLI_USER`, `OCI_CLI_FINGERPRINT`, `OCI_CLI_KEY_FILE`, `OCI_CLI_REGION`)
  - A config file at `~/.oci/config`
  - Instance principal (when running from an OCI compute instance)
- The tenancy OCID (`TF_VAR_tenancy_id`) and, for most examples, a target compartment OCID (`TF_VAR_compartment_id`)
- **The `oci` provider must be configured for the tenancy home region.** IAM is a
  home-region service; writes made against any other region fail.

## Quick start (free, no credentials needed)

`tests/unit_mappings.tftest.hcl` exercises input->config mapping logic (scope
defaulting, group-membership flattening and dedup, per-entry tag merging,
tenancy pinning of groups and dynamic groups, the `create = false` toggle) plus
a reject case for every `validation` block (bad OCIDs, names with spaces, empty
`matching_rule` / `statements`, malformed `version_date`). It runs against a
mocked OCI provider - no real resources, no OCI credentials, safe to run anytime:

```bash
terraform init
terraform test -filter=tests/unit_mappings.tftest.hcl
```

## Quick start (real resources, needs credentials)

```bash
export TF_VAR_tenancy_id="ocid1.tenancy.oc1.."
export TF_VAR_compartment_id="ocid1.compartment.oc1.."
terraform init
terraform test -filter=tests/simple.tftest.hcl
```

## Running all tests

```bash
export TF_VAR_tenancy_id="ocid1.tenancy.oc1.."
export TF_VAR_compartment_id="ocid1.compartment.oc1.."
terraform init
terraform test
```

## Notes

- All tests except `tests/unit_mappings.tftest.hcl` use `command = apply`. They
  create and destroy **real** IAM resources. IAM resources are free, but they are
  tenancy-wide, so run them in a tenancy where that is acceptable.
- `tests/compartments.tftest.hcl` creates a three-level compartment hierarchy.
  **Compartment deletion is slow** (minutes each, bottom-up: a parent waits on its
  children), which is why the example raises `timeouts.delete`. On delete OCI
  renames the compartment with a random suffix, so the original name is free to
  reuse on the next run; the OCID is retained 90 days for audit. The teardown
  deletes everything the test created.
- Every apply test is re-runnable: no example creates an `enable_delete = false`
  compartment, so nothing is left behind.
- `tests/compartments.tftest.hcl` teardown depends on the OCI Identity control
  plane, which occasionally leaves a `DELETE_COMPARTMENT` work request queued for
  hours before it starts (a backend stall, not a config problem: the request
  shows `status: ACCEPTED`, `percent-complete: 0`, no errors). When that happens
  the test hits its delete timeout and exits with the compartments still in
  `DELETING` or `ACTIVE`. Check the work request with
  `oci iam work-request list --compartment-id <ocid>`; once it reports
  `SUCCEEDED` the compartments are gone. If Terraform already gave up, delete any
  survivors bottom-up with
  `oci iam compartment delete --compartment-id <ocid> --force --wait-for-state SUCCEEDED --wait-for-state FAILED`.
- To test group membership with real users, pass
  `TF_VAR_group_member_user_ids='["ocid1.user.oc1..aaaa"]'` to the `complete`
  example. By default no members are attached so the example applies in any
  tenancy.
- Policy statements in the examples reference well-known OCI verbs and
  resource-types (`manage all-resources`, `read buckets`, `use stream-pull`, ...).
  OCI validates statement syntax at apply time; a typo fails the apply with a
  `400-InvalidParameter`.
