################################################################################
# Core / Control
################################################################################

variable "create" {
  description = "Controls if resources should be created (master switch - affects all resources)"
  type        = bool
  default     = true
}

variable "tenancy_id" {
  description = <<-EOT
    The OCID of the tenancy (root compartment). Groups and dynamic groups can
    only exist in the tenancy, so they are always created here. Also the default
    scope for policies and the default parent for compartments when
    compartment_id is not set.
  EOT
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.tenancy\\.[a-z0-9.]+", var.tenancy_id))
    error_message = "tenancy_id must be a valid tenancy OCID starting with ocid1.tenancy."
  }
}

variable "compartment_id" {
  description = <<-EOT
    The OCID of the compartment used as the default policy attach point and the
    default parent for created compartments. Defaults to tenancy_id (the root
    compartment). Override per entry with policies[*].compartment_id and
    compartments[*].parent_id.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.compartment_id == null ? true : can(regex("^ocid1\\.(compartment|tenancy)\\.[a-z0-9.]+", var.compartment_id))
    error_message = "compartment_id must be a valid OCID starting with ocid1.compartment or ocid1.tenancy."
  }
}

variable "tags" {
  description = "A map of freeform tags to add to all resources. Applied at create time only (changes are ignored, matching the sibling OCI modules)"
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "defined_tags" {
  description = "A map of defined tags (namespace.key = value) to add to all resources. Applied at create time only (changes are ignored, matching the sibling OCI modules)"
  type        = map(string)
  default     = {}
  nullable    = false
}

################################################################################
# Compartments  (no AWS counterpart - closest analog is an Organizations OU)
################################################################################

variable "compartments" {
  description = <<-EOT
    Map of compartments to create, keyed by compartment name. Names must be
    unique within their parent. On delete OCI renames the compartment with a
    random suffix, so the original name is free to reuse right away.

    Per entry:
      description   (required) human-readable description
      parent_id     (optional) parent compartment OCID; defaults to compartment_id
      enable_delete (optional) let `terraform destroy` actually delete the
                    compartment. Defaults to true. The OCI provider defaults this
                    to false, which makes destroy remove the compartment from
                    state WITHOUT deleting it. Set back to false for compartments
                    that must outlive this Terraform state. A compartment with
                    enable_delete = false left as an active child will block
                    `terraform destroy` of its parent - keep such compartments at
                    the top level, not nested under other managed compartments.
      timeouts      (optional) object { delete = "<duration>" } (e.g.
                    { delete = "30m" }). Compartment deletion is asynchronous and
                    can be slow, especially for a parent waiting on children;
                    raise it for deep hierarchies. Only delete is configurable.
      tags          (optional) freeform tags merged over var.tags
      defined_tags  (optional) defined tags merged over var.defined_tags

    To build a nested hierarchy in one apply, either pass the whole tree here and
    let Terraform order it, or reference an earlier entry's output
    (module.iam.compartment_ids["<name>"]) as parent_id from a second module call.
  EOT
  type = map(object({
    description   = string
    parent_id     = optional(string)
    enable_delete = optional(bool, true)
    timeouts = optional(object({
      delete = optional(string)
    }))
    tags         = optional(map(string), {})
    defined_tags = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for name in keys(var.compartments) : can(regex("^[a-zA-Z0-9._-]{1,100}$", name))])
    error_message = "compartments keys are compartment names: 1-100 chars, letters/digits/period/hyphen/underscore, no spaces."
  }
}

################################################################################
# Groups  (maps to the iam-group submodule)
################################################################################

variable "groups" {
  description = <<-EOT
    Map of IAM groups to create, keyed by group name. Groups always live in the
    tenancy (an OCI constraint, not a choice).

    Per entry:
      description  (required) human-readable description (required by OCI)
      user_ids     (optional) list of user OCIDs to add to the group. Look up
                   existing users with the oci_identity_users data source.
                   Creating users is out of scope for this module.
      tags         (optional) freeform tags merged over var.tags
      defined_tags (optional) defined tags merged over var.defined_tags
  EOT
  type = map(object({
    description  = string
    user_ids     = optional(list(string), [])
    tags         = optional(map(string), {})
    defined_tags = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for name in keys(var.groups) : can(regex("^[a-zA-Z0-9._-]{1,100}$", name))])
    error_message = "groups keys are group names: 1-100 chars, letters/digits/period/hyphen/underscore, no spaces."
  }

  validation {
    condition = alltrue([
      for g in var.groups : alltrue([
        for uid in g.user_ids : can(regex("^ocid1\\.user\\.[a-z0-9.]+", uid))
      ])
    ])
    error_message = "Every entry in groups[*].user_ids must be a user OCID starting with ocid1.user."
  }
}

################################################################################
# Dynamic Groups  (no standalone AWS resource - replaces an iam-role trust policy)
################################################################################

variable "dynamic_groups" {
  description = <<-EOT
    Map of dynamic groups to create, keyed by dynamic group name. Dynamic groups
    always live in the tenancy.

    A dynamic group is the OCI way to express workload identity: instead of
    attaching a role to a workload, you write a rule that matches the workload
    (instances, functions, OKE pods, ...) and then grant that dynamic group in a
    policy.

    Per entry:
      description   (required) human-readable description
      matching_rule (required) the membership rule, e.g.
                    "ALL {instance.compartment.id = 'ocid1.compartment.oc1..aaaa'}"
                    or "ANY {resource.type = 'fnfunc', resource.compartment.id = '...'}"
      tags          (optional) freeform tags merged over var.tags
      defined_tags  (optional) defined tags merged over var.defined_tags
  EOT
  type = map(object({
    description   = string
    matching_rule = string
    tags          = optional(map(string), {})
    defined_tags  = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for name in keys(var.dynamic_groups) : can(regex("^[a-zA-Z0-9._-]{1,100}$", name))])
    error_message = "dynamic_groups keys are dynamic group names: 1-100 chars, letters/digits/period/hyphen/underscore, no spaces."
  }

  validation {
    condition = alltrue([
      for dg in var.dynamic_groups : length(trimspace(dg.matching_rule)) > 0
    ])
    error_message = "Every entry in dynamic_groups must set a non-empty matching_rule."
  }
}

################################################################################
# Policies  (maps to the iam-policy submodule)
################################################################################

variable "policies" {
  description = <<-EOT
    Map of IAM policies to create, keyed by policy name.

    An OCI policy is a named object attached to a compartment (or the tenancy)
    holding a list of statements in the OCI policy grammar:
      Allow <subject> to <verb> <resource-type> in <scope> [where <condition>]
    The module passes statements through verbatim; it does not generate or
    validate them.

    Per entry:
      description    (required) human-readable description (required by OCI)
      statements     (required) list of policy statement strings
      compartment_id (optional) compartment or tenancy OCID to attach the policy
                     to; defaults to compartment_id
      version_date   (optional) pin the policy-language version (YYYY-MM-DD); null
                     tracks the current language. Removing it later keeps the
                     current pin (OCI cannot clear it); re-create the policy to
                     unpin it
      tags           (optional) freeform tags merged over var.tags
      defined_tags   (optional) defined tags merged over var.defined_tags

    Statements can reference groups and dynamic groups created in the same apply
    by name, but prefer the unambiguous forms: `dynamic-group 'Default'/'name'`
    or `dynamic-group id ocid1...`.
  EOT
  type = map(object({
    description    = string
    statements     = list(string)
    compartment_id = optional(string)
    version_date   = optional(string)
    tags           = optional(map(string), {})
    defined_tags   = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for name in keys(var.policies) : can(regex("^[a-zA-Z0-9._-]{1,100}$", name))])
    error_message = "policies keys are policy names: 1-100 chars, letters/digits/period/hyphen/underscore, no spaces."
  }

  validation {
    condition = alltrue([
      for p in var.policies : length(p.statements) > 0
    ])
    error_message = "Every entry in policies must have at least one statement."
  }

  validation {
    condition = alltrue([
      for p in var.policies :
      p.version_date == null || can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", p.version_date))
    ])
    error_message = "policies[*].version_date must be null or a YYYY-MM-DD date string."
  }
}
