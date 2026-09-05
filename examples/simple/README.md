# Simple IAM

Configuration in this directory creates the smallest useful IAM setup: one
compartment, one group, and one policy that lets the group manage all resources
in that compartment.

## Usage

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

IAM resources are free, but they are tenancy-wide. Run `terraform destroy` when
you no longer need them. The compartment is created with `enable_delete = true`
(the module default), so destroy removes it.

Your `oci` provider must be configured for the tenancy home region.

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
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment to create the example compartment under and attach the policy to. Defaults to the tenancy root when null | `string` | `null` | no |
| <a name="input_tenancy_id"></a> [tenancy\_id](#input\_tenancy\_id) | The OCID of the tenancy (root compartment) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_compartment_id"></a> [compartment\_id](#output\_compartment\_id) | OCID of the created compartment |
| <a name="output_group_id"></a> [group\_id](#output\_group\_id) | OCID of the created group |
| <a name="output_policy_id"></a> [policy\_id](#output\_policy\_id) | OCID of the created policy |
| <a name="output_policy_statements"></a> [policy\_statements](#output\_policy\_statements) | Resolved statements on the created policy |
<!-- END_TF_DOCS -->
