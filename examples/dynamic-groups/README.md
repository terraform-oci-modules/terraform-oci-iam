# Dynamic Groups

Configuration in this directory creates two dynamic groups and the policies that
grant them:

- `ex-dyn-groups-instances` matches every compute instance in the target
  compartment (instance principal). It is granted read access to Object Storage.
- `ex-dyn-groups-functions` matches every function in the target compartment
  (resource principal). It is granted stream-pull and secret read.

This is the OCI replacement for an AWS IAM role plus an instance profile or an
IRSA trust policy: nothing is attached to the workload, the `matching_rule`
decides membership and a policy grants the group.

## Usage

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Set `TF_VAR_tenancy_id` and `TF_VAR_compartment_id`. Your `oci` provider must be
configured for the tenancy home region. Run `terraform destroy` when done.

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
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment whose instances and functions the dynamic groups should match, and where the policies are attached | `string` | n/a | yes |
| <a name="input_tenancy_id"></a> [tenancy\_id](#input\_tenancy\_id) | The OCID of the tenancy (root compartment) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dynamic_group_ids"></a> [dynamic\_group\_ids](#output\_dynamic\_group\_ids) | Map of dynamic group name => OCID |
| <a name="output_instance_matching_rule"></a> [instance\_matching\_rule](#output\_instance\_matching\_rule) | The matching rule on the instance dynamic group |
| <a name="output_policy_ids"></a> [policy\_ids](#output\_policy\_ids) | Map of policy name => OCID |
<!-- END_TF_DOCS -->
