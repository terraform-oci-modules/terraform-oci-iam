# Complete IAM

Configuration in this directory exercises every feature of the module in a single
call:

- two compartments (all `enable_delete = true`, the module default)
- two groups, one taking an optional list of existing user OCIDs as members
- two dynamic groups (instance principal, function resource principal)
- three policies: one tenancy-scoped with a pinned `version_date`, two
  compartment-scoped, referencing both groups and dynamic groups

The module's internal `depends_on` orders compartments and groups before the
policies that name them, so this all applies in one pass.

To keep a compartment out of Terraform's delete path, set `enable_delete = false`
on it - but keep such compartments top-level, since an `enable_delete = false`
child blocks deletion of its parent. See [../compartments](../compartments).

## Usage

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Set `TF_VAR_tenancy_id` (and optionally `TF_VAR_compartment_id`). To add real
members to the platform-admins group, pass
`TF_VAR_group_member_user_ids='["ocid1.user.oc1..aaaa"]'`. Your `oci` provider
must be configured for the tenancy home region.

Run `terraform destroy` when done - it removes everything this example created.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | >= 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_iam"></a> [iam](#module\_iam) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment to build the example hierarchy under and attach compartment-scoped policies to. Defaults to the tenancy root when null | `string` | `null` | no |
| <a name="input_group_member_user_ids"></a> [group\_member\_user\_ids](#input\_group\_member\_user\_ids) | Optional list of existing user OCIDs to add to the platform-admins group. Left empty by default so the example applies cleanly in any tenancy | `list(string)` | `[]` | no |
| <a name="input_tenancy_id"></a> [tenancy\_id](#input\_tenancy\_id) | The OCID of the tenancy (root compartment) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_compartment_ids"></a> [compartment\_ids](#output\_compartment\_ids) | Map of compartment name => OCID |
| <a name="output_dynamic_group_ids"></a> [dynamic\_group\_ids](#output\_dynamic\_group\_ids) | Map of dynamic group name => OCID |
| <a name="output_group_ids"></a> [group\_ids](#output\_group\_ids) | Map of group name => OCID |
| <a name="output_group_memberships"></a> [group\_memberships](#output\_group\_memberships) | Map of group name => member user OCIDs |
| <a name="output_policy_ids"></a> [policy\_ids](#output\_policy\_ids) | Map of policy name => OCID |
<!-- END_TF_DOCS -->
