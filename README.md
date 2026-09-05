# OCI IAM Terraform Module

Terraform module which creates IAM resources on Oracle Cloud Infrastructure (OCI):
**compartments, groups, dynamic groups, and policies**, plus group membership.

Designed to be familiar to users of the [terraform-aws-modules/iam/aws](https://github.com/terraform-aws-modules/terraform-aws-iam)
module, mapped to the authorization primitives OCI actually has. AWS IAM and OCI IAM
are structurally different (no roles, statements instead of JSON documents, policies
attached to compartments rather than principals) - see
[docs/feature_parity.md](docs/feature_parity.md) for the full mapping and the design
rationale.

## Usage

```hcl
module "iam" {
  source  = "terraform-oci-modules/iam/oci"
  version = "~> 0.1"

  tenancy_id     = var.tenancy_id
  compartment_id = var.compartment_id # default scope for policies + parent for compartments

  compartments = {
    platform = { description = "Platform team workloads" }
  }

  groups = {
    platform-admins = {
      description = "Platform administrators"
      user_ids    = ["ocid1.user.oc1..aaaa"] # existing users, looked up elsewhere
    }
  }

  dynamic_groups = {
    platform-instances = {
      description   = "Compute instances in the platform compartment"
      matching_rule = "ALL {instance.compartment.id = '${var.compartment_id}'}"
    }
  }

  policies = {
    platform-admins = {
      description = "Platform admins manage everything in their compartment"
      statements  = ["Allow group platform-admins to manage all-resources in compartment platform"]
    }
  }

  tags = {
    Terraform = "true"
  }
}
```

## Home region

IAM is a home-region service. Configure the `oci` provider for your tenancy's home
region; writes made against any other region fail. This module declares no provider
alias, matching the sibling OCI modules.

## Scope: `tenancy_id` vs `compartment_id`

Groups and dynamic groups can only exist in the tenancy (an OCI constraint), so the
module always creates them there. Policies and compartments default to
`compartment_id` (which itself defaults to `tenancy_id`) and can be overridden per
entry with `policies[*].compartment_id` and `compartments[*].parent_id`.

## Policies

An OCI policy is not attached to a principal. It is a named object on a compartment
(or the tenancy) holding statements in the OCI policy grammar:

```
Allow <subject> to <verb> <resource-type> in <scope> [where <condition>]
```

The module passes `statements` through verbatim. It does not generate or validate
them - OCI validates syntax at apply time. Statements can reference groups and
dynamic groups created in the same apply; the module adds an internal `depends_on`
so a single apply creates compartments and groups before the policies that name
them. Prefer the unambiguous subject forms: `dynamic-group 'Default'/'name'` or
`dynamic-group id ocid1...`.

## Dynamic groups

A dynamic group is the OCI replacement for an AWS IAM role plus an instance profile
or IRSA trust policy. Nothing is attached to the workload: a `matching_rule` decides
membership and a policy grants the group.

```hcl
dynamic_groups = {
  functions = {
    description   = "All functions in the compartment"
    matching_rule = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_id}'}"
  }
}
```

## Compartments

`compartments[*].enable_delete` defaults to `true` (the OCI provider default is
`false`, which makes `terraform destroy` drop the compartment from state without
deleting it). Set it back to `false` for compartments that must outlive the state.
On an actual delete OCI renames the compartment with a random suffix, so the
original name is immediately reusable; the OCID is retained 90 days for audit.

**Keep `enable_delete = false` compartments at the top level.** OCI will not delete
a compartment that still has active children, so an `enable_delete = false` child
blocks `terraform destroy` of its parent indefinitely.

`parent_id` takes a compartment OCID. Build a hierarchy with one module call per
level, each referencing the previous level's `compartment_ids` output - see
[examples/compartments](examples/compartments). Compartment deletion is slow and
asynchronous; raise `compartments[*].timeouts.delete` for deep hierarchies.

## Tags

OCI supports two tag types, both mapped:

| Variable       | OCI tag type    |
| -------------- | --------------- |
| `tags`         | `freeform_tags` |
| `defined_tags` | `defined_tags`  |

Every map entry (`compartments`, `groups`, `dynamic_groups`, `policies`) accepts its
own `tags` / `defined_tags` that merge over the module-wide values. Following the
sibling OCI modules, tags are applied at create time and later changes are ignored
(`lifecycle { ignore_changes = [defined_tags, freeform_tags] }`) to avoid drift from
OCI's auto-injected `Oracle-Tags` defaults.

## Adopting existing IAM resources

To bring resources that already exist in a tenancy under this module, use
`import` blocks (Terraform 1.5+). The `to` address is the map key you give the
resource in the corresponding variable:

```hcl
import {
  to = module.iam.oci_identity_compartment.this["platform"]
  id = "ocid1.compartment.oc1..aaaa"
}

import {
  to = module.iam.oci_identity_group.this["platform-admins"]
  id = "ocid1.group.oc1..aaaa"
}

import {
  to = module.iam.oci_identity_policy.this["platform-admins"]
  id = "ocid1.policy.oc1..aaaa"
}
```

Group memberships import as
`module.iam.oci_identity_user_group_membership.this["<group-key>/<user-ocid>"]`.
Run `terraform plan` and reconcile any diffs (often just `description` or tags)
before applying.

## What this module does not do

Out of scope: user creation and credentials (Identity Domains territory - the module
consumes existing user OCIDs for membership only), identity providers, OKE workload
identity presets (those belong in `terraform-oci-oke`), canned policy content, and
tag-namespace governance. Not applicable: everything from the `iam-role` submodule
(OCI has no role resource). See [docs/feature_parity.md](docs/feature_parity.md).

## Examples

- [simple](examples/simple) - Minimal setup: one compartment, one group, one policy granting the group `manage all-resources` in that compartment
- [complete](examples/complete) - Two compartments, two groups (one taking an optional member list), instance + function dynamic groups, one tenancy-scoped and two compartment-scoped policies
- [dynamic-groups](examples/dynamic-groups) - Instance-principal and function resource-principal matching rules, each paired with the policy that grants it
- [compartments](examples/compartments) - Three-level compartment hierarchy built with one module call per level, `timeouts.delete` raised on the parents

## Wrappers

- [wrappers](wrappers) - Terragrunt-style `for_each` wrapper for the root module

## Testing

Each example ships with a [`terraform test`](https://developer.hashicorp.com/terraform/language/tests) file that applies real OCI resources, asserts key outputs, then destroys on completion. A credential-less mock suite (`tests/unit_mappings.tftest.hcl`) covers the input-mapping logic. See [docs/testing.md](docs/testing.md) for prerequisites, OCI auth setup, and how to run the tests.

## AWS to OCI feature parity

See [docs/feature_parity.md](docs/feature_parity.md) for the full comparison against
`terraform-aws-modules/iam/aws`: feature, variable and output mapping, what is not
applicable to OCI, what is out of scope, and what is not yet implemented.

## Related Projects

### Official Oracle module

Oracle maintains official IAM building blocks under
[oracle-terraform-modules](https://github.com/oracle-terraform-modules) (for example
the `iam` submodule of the OKE and landing-zone modules).

**When to use this module:**
- You are migrating from AWS and want the same module layout and interface as `terraform-aws-modules/iam/aws`
- You want a consistent interface across AWS and OCI infrastructure

### Disclaimer

This is an independent community module and is **not affiliated with, endorsed by, or supported by Oracle Corporation**. Oracle Cloud Infrastructure (OCI) is a trademark of Oracle Corporation. This module uses the publicly available [OCI Terraform provider](https://registry.terraform.io/providers/oracle/oci/latest) under its Mozilla Public License 2.0.

## License

[Apache 2.0](LICENSE)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_oci"></a> [oci](#provider\_oci) | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [oci_identity_compartment.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_compartment) | resource |
| [oci_identity_dynamic_group.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_dynamic_group) | resource |
| [oci_identity_group.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_group) | resource |
| [oci_identity_policy.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_policy) | resource |
| [oci_identity_user_group_membership.this](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_user_group_membership) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | The OCID of the compartment used as the default policy attach point and the<br/>default parent for created compartments. Defaults to tenancy\_id (the root<br/>compartment). Override per entry with policies[*].compartment\_id and<br/>compartments[*].parent\_id. | `string` | `null` | no |
| <a name="input_compartments"></a> [compartments](#input\_compartments) | Map of compartments to create, keyed by compartment name. Names must be<br/>unique within their parent. On delete OCI renames the compartment with a<br/>random suffix, so the original name is free to reuse right away.<br/><br/>Per entry:<br/>  description   (required) human-readable description<br/>  parent\_id     (optional) parent compartment OCID; defaults to compartment\_id<br/>  enable\_delete (optional) let `terraform destroy` actually delete the<br/>                compartment. Defaults to true. The OCI provider defaults this<br/>                to false, which makes destroy remove the compartment from<br/>                state WITHOUT deleting it. Set back to false for compartments<br/>                that must outlive this Terraform state. A compartment with<br/>                enable\_delete = false left as an active child will block<br/>                `terraform destroy` of its parent - keep such compartments at<br/>                the top level, not nested under other managed compartments.<br/>  timeouts      (optional) object { delete = "<duration>" } (e.g.<br/>                { delete = "30m" }). Compartment deletion is asynchronous and<br/>                can be slow, especially for a parent waiting on children;<br/>                raise it for deep hierarchies. Only delete is configurable.<br/>  tags          (optional) freeform tags merged over var.tags<br/>  defined\_tags  (optional) defined tags merged over var.defined\_tags<br/><br/>To build a nested hierarchy in one apply, either pass the whole tree here and<br/>let Terraform order it, or reference an earlier entry's output<br/>(module.iam.compartment\_ids["<name>"]) as parent\_id from a second module call. | <pre>map(object({<br/>    description   = string<br/>    parent_id     = optional(string)<br/>    enable_delete = optional(bool, true)<br/>    timeouts = optional(object({<br/>      delete = optional(string)<br/>    }))<br/>    tags         = optional(map(string), {})<br/>    defined_tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_create"></a> [create](#input\_create) | Controls if resources should be created (master switch - affects all resources) | `bool` | `true` | no |
| <a name="input_defined_tags"></a> [defined\_tags](#input\_defined\_tags) | A map of defined tags (namespace.key = value) to add to all resources. Applied at create time only (changes are ignored, matching the sibling OCI modules) | `map(string)` | `{}` | no |
| <a name="input_dynamic_groups"></a> [dynamic\_groups](#input\_dynamic\_groups) | Map of dynamic groups to create, keyed by dynamic group name. Dynamic groups<br/>always live in the tenancy.<br/><br/>A dynamic group is the OCI way to express workload identity: instead of<br/>attaching a role to a workload, you write a rule that matches the workload<br/>(instances, functions, OKE pods, ...) and then grant that dynamic group in a<br/>policy.<br/><br/>Per entry:<br/>  description   (required) human-readable description<br/>  matching\_rule (required) the membership rule, e.g.<br/>                "ALL {instance.compartment.id = 'ocid1.compartment.oc1..aaaa'}"<br/>                or "ANY {resource.type = 'fnfunc', resource.compartment.id = '...'}"<br/>  tags          (optional) freeform tags merged over var.tags<br/>  defined\_tags  (optional) defined tags merged over var.defined\_tags | <pre>map(object({<br/>    description   = string<br/>    matching_rule = string<br/>    tags          = optional(map(string), {})<br/>    defined_tags  = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Map of IAM groups to create, keyed by group name. Groups always live in the<br/>tenancy (an OCI constraint, not a choice).<br/><br/>Per entry:<br/>  description  (required) human-readable description (required by OCI)<br/>  user\_ids     (optional) list of user OCIDs to add to the group. Look up<br/>               existing users with the oci\_identity\_users data source.<br/>               Creating users is out of scope for this module.<br/>  tags         (optional) freeform tags merged over var.tags<br/>  defined\_tags (optional) defined tags merged over var.defined\_tags | <pre>map(object({<br/>    description  = string<br/>    user_ids     = optional(list(string), [])<br/>    tags         = optional(map(string), {})<br/>    defined_tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_policies"></a> [policies](#input\_policies) | Map of IAM policies to create, keyed by policy name.<br/><br/>An OCI policy is a named object attached to a compartment (or the tenancy)<br/>holding a list of statements in the OCI policy grammar:<br/>  Allow <subject> to <verb> <resource-type> in <scope> [where <condition>]<br/>The module passes statements through verbatim; it does not generate or<br/>validate them.<br/><br/>Per entry:<br/>  description    (required) human-readable description (required by OCI)<br/>  statements     (required) list of policy statement strings<br/>  compartment\_id (optional) compartment or tenancy OCID to attach the policy<br/>                 to; defaults to compartment\_id<br/>  version\_date   (optional) pin the policy-language version (YYYY-MM-DD); null<br/>                 tracks the current language<br/>  tags           (optional) freeform tags merged over var.tags<br/>  defined\_tags   (optional) defined tags merged over var.defined\_tags<br/><br/>Statements can reference groups and dynamic groups created in the same apply<br/>by name, but prefer the unambiguous forms: `dynamic-group 'Default'/'name'`<br/>or `dynamic-group id ocid1...`. | <pre>map(object({<br/>    description    = string<br/>    statements     = list(string)<br/>    compartment_id = optional(string)<br/>    version_date   = optional(string)<br/>    tags           = optional(map(string), {})<br/>    defined_tags   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of freeform tags to add to all resources. Applied at create time only (changes are ignored, matching the sibling OCI modules) | `map(string)` | `{}` | no |
| <a name="input_tenancy_id"></a> [tenancy\_id](#input\_tenancy\_id) | The OCID of the tenancy (root compartment). Groups and dynamic groups can<br/>only exist in the tenancy, so they are always created here. Also the default<br/>scope for policies and the default parent for compartments when<br/>compartment\_id is not set. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_compartment_ids"></a> [compartment\_ids](#output\_compartment\_ids) | Map of compartment name => OCID for every created compartment |
| <a name="output_compartments"></a> [compartments](#output\_compartments) | Created compartments keyed by name (curated fields, not the raw provider object) |
| <a name="output_dynamic_group_ids"></a> [dynamic\_group\_ids](#output\_dynamic\_group\_ids) | Map of dynamic group name => OCID for every created dynamic group |
| <a name="output_dynamic_groups"></a> [dynamic\_groups](#output\_dynamic\_groups) | Created dynamic groups keyed by name (curated fields, not the raw provider object) |
| <a name="output_group_ids"></a> [group\_ids](#output\_group\_ids) | Map of group name => OCID for every created group |
| <a name="output_group_memberships"></a> [group\_memberships](#output\_group\_memberships) | Map of group name => list of member user OCIDs, derived from the created oci\_identity\_user\_group\_membership resources (proves the memberships exist, not just that they were requested) |
| <a name="output_groups"></a> [groups](#output\_groups) | Created groups keyed by name (curated fields, not the raw provider object) |
| <a name="output_policies"></a> [policies](#output\_policies) | Created policies keyed by name, including the resolved statements (curated fields, not the raw provider object) |
| <a name="output_policy_ids"></a> [policy\_ids](#output\_policy\_ids) | Map of policy name => OCID for every created policy |
<!-- END_TF_DOCS -->
