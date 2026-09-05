# IAM (AWS) to IAM (OCI) feature parity

Comparison against [`terraform-aws-modules/iam`](https://github.com/terraform-aws-modules/terraform-aws-iam)
v6.8.1. That module is a collection of eight submodules (`iam-account`, `iam-group`,
`iam-oidc-provider`, `iam-policy`, `iam-read-only-policy`, `iam-role`,
`iam-role-for-service-accounts`, `iam-user`). This module is a single root module that
covers the authorization primitives OCI actually has: **compartments, groups, dynamic
groups, and policies**, plus group membership as the glue between them.

It is not a 1:1 mapping. AWS IAM and OCI IAM are structurally different:

- AWS attaches JSON policy documents to principals (users, groups, roles). OCI attaches
  a list of human-readable statements to a **compartment or the tenancy**, and each
  statement names the group or dynamic group it grants to.
- AWS has a **role** resource that principals assume. OCI has no role resource at all.
  Workload identity is expressed as a **dynamic group** (a rule that matches instances,
  functions, OKE workloads, etc.) plus a policy that grants that dynamic group.
- AWS users and their credentials live in IAM. On OCI the current home for human
  identities is **Identity Domains** (`oci_identity_domains_*`), a separate service.
  Legacy tenancy-level users still exist but are out of scope here.

Gaps are split three ways:

- [Not applicable](#not-applicable-to-oci): no OCI equivalent exists.
- [Out of scope](#out-of-scope): OCI supports it, this module deliberately does not.
- [Not yet implemented](#not-yet-implemented): the backlog.

Status values in the tables: `mapped` where the concept carries over, `n/a` where no OCI
equivalent exists, `OCI-only` for features with no AWS counterpart, `backlog` for
anything the OCI provider supports that this module does not expose yet.

## Feature mapping

### Core / control

| Feature                  | AWS                          | OCI                                  | Status   |
| ------------------------ | ---------------------------- | ------------------------------------ | -------- |
| Create toggle            | `create` (per submodule)     | `create`                             | mapped   |
| Tenancy scoping          | AWS account (implicit)       | `tenancy_id`                         | OCI-only |
| Default compartment      | none                         | `compartment_id` (default: tenancy)  | OCI-only |
| Per-resource region      | `region` (in one submodule)  | none                                 | n/a      |
| IAM path                 | `path` / `name_prefix`       | none                                 | n/a      |

> **`tenancy_id` vs `compartment_id`**: OCI groups and dynamic groups can only exist in
> the tenancy (root compartment), so the module always creates them there. Policies and
> compartments default to `compartment_id` (itself defaulting to `tenancy_id`) and can be
> overridden per entry. There is no per-resource region: IAM is a home-region service and
> the provider carries the region.
>
> **No `path`, no `name_prefix`**: AWS uses IAM paths (`/team/`) and generated name
> prefixes for uniqueness and grouping. OCI uses compartments for hierarchy and requires
> caller-chosen names that are unique within their scope, so both concepts drop out.

### Compartments

No AWS submodule. AWS's nearest analog is an Organizations OU, which
`terraform-aws-modules/iam` does not cover.

| Feature                    | AWS  | OCI                                    | Status   |
| -------------------------- | ---- | ------------------------------------- | -------- |
| Create compartments (map)  | none | `compartments`                        | OCI-only |
| Description                | none | `compartments[*].description`         | OCI-only |
| Nesting / parent           | none | `compartments[*].parent_id`           | OCI-only |
| Allow Terraform to delete  | none | `compartments[*].enable_delete`       | OCI-only |
| Delete/create timeouts     | none | `compartments[*].timeouts`            | OCI-only |
| Freeform / defined tags    | none | `compartments[*].tags` / `.defined_tags` | OCI-only |

> **`enable_delete`**: `oci_identity_compartment` defaults `enable_delete = false`, which
> means `terraform destroy` **removes the compartment from state without deleting it**.
> The module surfaces this per entry and defaults it to `true` so destroy behaves as
> expected; set it back to `false` for compartments that must outlive the Terraform
> state. On an actual delete OCI renames the compartment with a random suffix so the
> original name is immediately reusable; the OCID is retained for 90 days for audit.
>
> **`enable_delete = false` blocks parent deletion.** OCI refuses to delete a compartment
> that still has active children. A child left behind by `enable_delete = false` will
> therefore block `terraform destroy` of its parent indefinitely ("expected DELETED, got
> ACTIVE"). Keep `enable_delete = false` compartments at the top level, never nested under
> another managed compartment.
>
> **Nesting**: `parent_id` takes an existing compartment OCID. To build a hierarchy in
> one apply, reference an earlier entry's output
> (`module.iam.compartment_ids["platform"]`) from a second module call, or pass the
> whole tree to one call and let Terraform order it. OCI allows up to six levels of
> nesting.
>
> **`timeouts`**: compartment deletion is asynchronous and slow, and a parent has to wait
> for every child to finish deleting first. For deep hierarchies raise
> `timeouts.delete` (e.g. `{ delete = "30m" }`) so Terraform does not abort a
> still-progressing delete.

### Groups

AWS submodule: `iam-group`.

| Feature                        | AWS                                    | OCI                                         | Status   |
| ------------------------------ | -------------------------------------- | ------------------------------------------- | -------- |
| Create groups (map)            | one group per module call              | `groups` (map, name = key)                  | mapped   |
| Description                    | none (AWS groups have no description)  | `groups[*].description` (required by OCI)   | OCI-only |
| Membership                     | `users` (list of user names)           | `groups[*].user_ids` (list of user OCIDs)   | mapped   |
| Freeform / defined tags        | `tags`                                 | `groups[*].tags` / `.defined_tags`          | mapped   |
| Attach managed policies        | `policies` (map of ARNs)               | see `policies` map, statements name the group | n/a (different model) |
| Inline permissions             | `permissions`, `create_policy`         | see `policies` map                          | n/a (different model) |
| Self-management policy         | `enable_self_management_permissions`   | none (write the statement yourself)         | n/a      |
| MFA enforcement policy         | `enable_mfa_enforcement`               | none (write the statement yourself)         | n/a      |
| Cross-account user references  | `users_account_id`                     | none                                        | n/a      |

> **Why policy attachment is n/a**: an OCI policy is not attached to a group. It is a
> named object in a compartment holding statements like
> `Allow group platform-admins to manage all-resources in compartment platform`. The
> group is named *inside the statement*. So instead of `iam-group`'s `policies` and
> `permissions`, this module has a top-level `policies` map whose statements reference
> groups (and dynamic groups) by name. Canned policy generators (`enable_mfa_enforcement`
> and similar) are out: on OCI you write the one statement you want.
>
> **`user_ids`**: OCI group membership is by user OCID, created as
> `oci_identity_user_group_membership`. Look up existing user OCIDs with the
> `oci_identity_users` data source. Creating users is out of scope (see below).

### Dynamic groups

AWS's closest analog is the trust policy of an `iam-role` (which principals/services may
assume it), but there is no standalone AWS resource.

| Feature                    | AWS                              | OCI                                    | Status   |
| -------------------------- | -------------------------------- | ------------------------------------- | -------- |
| Create dynamic groups (map)| trust policy on a role           | `dynamic_groups` (map, name = key)     | OCI-only |
| Matching rule              | `trust_policy_permissions` etc.  | `dynamic_groups[*].matching_rule`      | OCI-only |
| Description                | `description`                    | `dynamic_groups[*].description`        | mapped   |
| Freeform / defined tags    | `tags`                           | `dynamic_groups[*].tags` / `.defined_tags` | mapped |

> **What a dynamic group replaces**: on AWS you create a role, write a trust policy
> saying "the EC2 service (or an OIDC subject) may assume this", attach permission
> policies, and attach the role to the workload. On OCI you create a dynamic group with a
> `matching_rule` such as
> `ALL {instance.compartment.id = 'ocid1.compartment...'}` or
> `ANY {resource.type = 'fnfunc', resource.compartment.id = '...'}`, then grant it in a
> policy. Nothing is attached to the workload; membership is evaluated from the rule at
> request time. Dynamic groups always live in the tenancy.

### Policies

AWS submodules: `iam-policy` (a managed policy), `iam-read-only-policy` (a canned
read-only document).

| Feature                    | AWS                                  | OCI                                    | Status   |
| -------------------------- | ------------------------------------ | ------------------------------------- | -------- |
| Create policies (map)      | one policy per module call           | `policies` (map, name = key)           | mapped   |
| Statements                 | `policy` (JSON document string)      | `policies[*].statements` (list of strings) | mapped (different language) |
| Attach point               | attached to principals               | `policies[*].compartment_id` (compartment or tenancy) | n/a (different model) |
| Description                | `description`                        | `policies[*].description` (required by OCI) | mapped |
| Policy language version    | none                                 | `policies[*].version_date`             | OCI-only |
| Freeform / defined tags    | `tags`                               | `policies[*].tags` / `.defined_tags`   | mapped   |
| Canned read-only document  | `iam-read-only-policy`               | none                                   | n/a      |

> **Statement language**: AWS policy is a JSON document, usually built with the
> `aws_iam_policy_document` data source, listing `Effect` / `Action` / `Resource` /
> `Condition`. OCI statements are plain strings in the OCI policy grammar:
> `Allow <subject> to <verb> <resource-type> in <scope> [where <condition>]`. The module
> takes them verbatim; it does not generate or validate them. Statements that name a
> group or dynamic group created in the same apply work because the reference is a
> string, but prefer the unambiguous forms (`dynamic-group 'Default'/'name'` or
> `dynamic-group id ocid1...`).
>
> **`version_date`**: pinning `version_date` freezes the policy against a dated version
> of the OCI policy language, so later platform changes to verb or resource-type
> semantics do not silently widen or narrow a grant. Leaving it null tracks the current
> language.
>
> **Apply ordering**: OCI validates each statement against existing groups, dynamic
> groups and compartments at policy-create time. The module puts a `depends_on` from
> every policy to all created groups, dynamic groups and compartments, so a single apply
> that defines all four in one module call succeeds without the caller ordering anything.

### Group membership

| Feature              | AWS                              | OCI                                  | Status   |
| -------------------- | -------------------------------- | ------------------------------------ | -------- |
| Add users to a group | `aws_iam_group_membership`       | `oci_identity_user_group_membership` (from `groups[*].user_ids`) | mapped |

### Submodules and wrappers

| AWS submodule                   | OCI                                            | Status                          |
| ------------------------------- | --------------------------------------------- | ------------------------------- |
| `iam-group`                     | root module (`groups`)                         | mapped                          |
| `iam-policy`                    | root module (`policies`)                       | mapped                          |
| (no AWS submodule)              | root module (`compartments`, `dynamic_groups`) | OCI-only                        |
| `iam-account`                   | none                                          | backlog (`authentication_policy`) |
| `iam-read-only-policy`          | none                                          | out of scope                    |
| `iam-oidc-provider`             | none                                          | out of scope (Identity Domains) |
| `iam-role`                      | none                                          | n/a (no role resource in OCI)   |
| `iam-role-for-service-accounts` | none                                          | out of scope (belongs in `terraform-oci-oke`) |
| `iam-user`                      | none                                          | out of scope (Identity Domains) |
| `wrappers/`                     | `wrappers/`                                    | mapped                          |

## Variable mapping

Equivalent concept, different name. Anything not listed maps by an identical name.

| AWS                          | OCI                             | Notes                                                        |
| ---------------------------- | ------------------------------- | ---------------------------------------------------------- |
| `create`                     | `create`                        | master toggle                                              |
| `iam-group` `name` + one call per group | `groups` (map)         | one module call manages many groups, keyed by name         |
| `iam-group.users`            | `groups[*].user_ids`            | AWS: user names. OCI: user OCIDs (`oci_identity_users` data source) |
| `iam-group.tags`             | `groups[*].tags`                | freeform tags, mapped to the provider's `freeform_tags`    |
| `iam-policy` `name` + one call per policy | `policies` (map)      | keyed by name                                              |
| `iam-policy.policy`          | `policies[*].statements`        | JSON document to a list of OCI statement strings           |
| `iam-policy.description`     | `policies[*].description`       | required by OCI                                            |
| `iam-account.*password*`     | none                            | backlog, see `authentication_policy`                       |

OCI-only variables, no AWS counterpart:

| OCI variable                       | What it does                                                          |
| ---------------------------------- | -------------------------------------------------------------------- |
| `tenancy_id`                       | tenancy OCID; groups and dynamic groups are always created here       |
| `compartment_id`                   | default attach point for policies and default parent for compartments |
| `compartments`                     | map of compartments to create                                         |
| `compartments[*].parent_id`        | parent compartment OCID for nesting                                   |
| `compartments[*].enable_delete`    | let `terraform destroy` actually delete the compartment               |
| `compartments[*].timeouts`         | create/update/delete timeout overrides for slow compartment deletes   |
| `dynamic_groups`                   | map of dynamic groups to create                                       |
| `dynamic_groups[*].matching_rule`  | the rule that decides membership (`ALL {...}` / `ANY {...}`)           |
| `policies[*].compartment_id`       | per-policy attach point (compartment or tenancy)                      |
| `policies[*].version_date`         | pin the policy-language version                                       |
| `defined_tags` on every entry      | OCI's tag-namespace system, alongside freeform `tags`                 |

## Output mapping

| AWS (per submodule)         | OCI                                  | Notes                             |
| --------------------------- | ------------------------------------ | --------------------------------- |
| `iam-group` `id` / `name`   | `group_ids` (map name to OCID)       | keyed by group name               |
| `iam-group.users`           | `group_memberships`                  | map of group name to member user OCIDs, read back from the created membership resources |
| `iam-policy` `id` / `name`  | `policy_ids` (map name to OCID)      | keyed by policy name              |
| `iam-policy.policy`         | `policies` (curated objects)         | includes the resolved `statements` |
| (none)                      | `compartment_ids` (map name to OCID) | keyed by compartment name         |
| (none)                      | `dynamic_group_ids` (map name to OCID) | keyed by dynamic group name     |

Every AWS `*_arn` output is n/a: OCI identifies resources by OCID, exposed as `*_ids`.
AWS `unique_id` is n/a. All `iam-user` credential outputs (`access_key_*`,
`login_profile_*`, `ssh_key_*`) are n/a: user creation is out of scope.

OCI-only outputs: `compartments`, `groups`, `dynamic_groups`, `policies` (per-name
maps of curated attributes - id, name, description, state, time_created, plus
`statements` / `matching_rule` / `parent_id` / `enable_delete` where relevant - not
the raw provider objects, which expose deprecated `ETag` fields), and
`group_memberships`.

## Not applicable to OCI

AWS-platform constructs with no OCI counterpart. The corresponding variables are absent
rather than stubbed.

| AWS feature                                                        | Why it does not port                                                                                                   |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `iam-role` (the entire submodule)                                 | OCI has no role resource. Assumable-identity use cases are covered by dynamic groups plus a policy grant.              |
| `iam-role` instance profile (`create_instance_profile`)           | Nothing is attached to a workload on OCI; a dynamic group's rule matches it.                                          |
| `iam-role` `max_session_duration`, `permissions_boundary`         | No session or boundary concept on OCI IAM.                                                                            |
| `iam-role` OIDC / GitHub / Bitbucket / SAML trust blocks          | Federated trust lives in Identity Domains, not tenancy IAM. GitHub OIDC to OCI is done through an Identity Domain identity provider. |
| `path`, `name_prefix`, `use_name_prefix`                          | OCI uses compartments for hierarchy and requires explicit unique names.                                              |
| `region` (in `iam-role-for-service-accounts`)                     | IAM is a home-region service; the provider carries the region.                                                        |
| `iam-group` `enable_self_management_permissions`, `enable_mfa_enforcement` | These generate canned JSON policy documents. On OCI you write the single statement you want.                  |
| Every `*_arn` / `unique_id` output                                | OCI uses OCIDs.                                                                                                        |

## Out of scope

OCI supports these; this module does not.

- **User creation and credentials.** `oci_identity_user`, `oci_identity_api_key`,
  `oci_identity_auth_token`, `oci_identity_customer_secret_key`,
  `oci_identity_smtp_credential`, `oci_identity_ui_password`, `oci_identity_db_credential`.
  Human identities belong in Identity Domains now, and machine credentials have a
  different lifecycle owner than an authorization structure. The module consumes existing
  user OCIDs for group membership; it does not create users. A dedicated
  `terraform-oci-identity-domain` module is the right home if this is needed.
- **Identity providers.** `oci_identity_identity_provider` (SAML 2.0) and the
  `oci_identity_domains_*` identity-provider and social-login resources. Federation setup
  is a one-time tenancy concern, not part of day-to-day authorization.
- **OKE workload identity presets.** The analog of
  `iam-role-for-service-accounts` (canned grants for cluster-autoscaler, external-dns,
  and so on) belongs in `terraform-oci-oke` alongside the cluster, where the compartment
  and cluster OCIDs it needs already exist.
- **Read-only / canned policy content.** `iam-read-only-policy` ships an opinionated
  document. This module treats statement content as caller-owned input.
- **Tag namespaces, tag definitions, tag defaults.** `oci_identity_tag_namespace`,
  `oci_identity_tag`, `oci_identity_tag_default`. Tag governance is its own concern and a
  candidate for a separate `terraform-oci-tags` module; this module only *applies*
  freeform and defined tags to the resources it creates.
- **Network sources.** `oci_identity_network_source` (IP allowlists referenced from
  policy `where` clauses). A natural extension of the policy feature, listed in the
  backlog rather than out of scope.

## Not yet implemented

| Gap                          | Detail                                                                                                                                     | AWS analog          |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| `authentication_policy`      | `oci_identity_authentication_policy`: tenancy-wide password rules (length, character classes, username containment) and a network policy referencing network sources. Singleton per compartment. | `iam-account` password policy |
| Network sources              | `oci_identity_network_source`: named public/VCN IP lists used in policy `where request.networkSource.name = ...` conditions.               | none                |
| Compartment tree helper      | A single-call nested hierarchy (parent references by map key rather than OCID), if the flat `parent_id` form proves awkward in practice.   | none                |
| Home-region guard            | A `check` block that fails early when the `oci` provider is pointed at a non-home region (IAM writes fail late otherwise). Blocked: the OCI provider exposes no data source for the provider's currently configured region, so the comparison cannot be built. Documented in the README instead. | none |

## Examples

| Example           | What it covers                                                                                                    | AWS counterpart          |
| ----------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `simple`          | One compartment, one group, one policy granting the group `manage all-resources` in that compartment              | `iam-group`              |
| `complete`        | Two compartments (one with a per-entry tag), groups (members optional via a variable), dynamic groups (instance + resource principals), one tenancy-scoped policy with a pinned `version_date` plus two compartment-scoped policies | `iam-group` + `iam-policy` |
| `dynamic-groups`  | Instance-principal and resource-principal (`fnfunc`, OKE) matching rules with the policies that grant them        | none                     |
| `compartments`    | A three-level compartment hierarchy (one module call per level) with `timeouts.delete` raised on the upper levels | none                     |

AWS examples with no OCI counterpart: `iam-account`, `iam-oidc-provider`, `iam-role`,
`iam-role-for-service-accounts`, `iam-user`, `iam-read-only-policy`.
