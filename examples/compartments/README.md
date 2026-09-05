# Compartments

Configuration in this directory builds a three-level compartment hierarchy with
one module call per level:

```
ex-compartments                 (level 1)
└─ ex-compartments-prod          (level 2)
   └─ ex-compartments-prod-app   (level 3)
```

`parent_id` takes a compartment OCID, so each level references the previous
level's `compartment_ids` output.

If an upstream module call can be toggled off with `create = false`, its
`compartment_ids` output is `{}` and `module.<call>.compartment_ids["<name>"]`
raises a key error. Guard the downstream `parent_id` with
`try(module.root.compartment_ids["ex-compartments"], null)` in that case.

The upper levels raise `timeouts.delete` to `30m`: compartment deletion is
asynchronous and a parent has to wait for its children to finish deleting first.

To keep a compartment out of Terraform's delete path, set `enable_delete = false`
on it. `terraform destroy` then drops it from state without deleting it. Keep
such compartments **top-level** - OCI refuses to delete a compartment that still
has active children, so an `enable_delete = false` child would block deletion of
its parent forever.

## Usage

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Set `TF_VAR_tenancy_id`. Your `oci` provider must be configured for the tenancy
home region.

> **Deleting compartments is slow** (minutes each, bottom-up). On delete OCI
> renames the compartment with a random suffix so the original name is free to
> reuse right away; the OCID itself is retained for 90 days.

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
| <a name="module_environments"></a> [environments](#module\_environments) | ../../ | n/a |
| <a name="module_root"></a> [root](#module\_root) | ../../ | n/a |
| <a name="module_teams"></a> [teams](#module\_teams) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment to create the top of the example hierarchy under. Defaults to the tenancy root when null | `string` | `null` | no |
| <a name="input_tenancy_id"></a> [tenancy\_id](#input\_tenancy\_id) | The OCID of the tenancy (root compartment) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_environment_compartment_ids"></a> [environment\_compartment\_ids](#output\_environment\_compartment\_ids) | Map of environment compartment name => OCID |
| <a name="output_root_compartment_id"></a> [root\_compartment\_id](#output\_root\_compartment\_id) | OCID of the top-level compartment |
| <a name="output_team_compartment_ids"></a> [team\_compartment\_ids](#output\_team\_compartment\_ids) | Map of team compartment name => OCID |
<!-- END_TF_DOCS -->
