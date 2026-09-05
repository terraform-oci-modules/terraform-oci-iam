################################################################################
# Compartments
################################################################################

output "compartment_ids" {
  description = "Map of compartment name => OCID for every created compartment"
  value       = { for k, v in oci_identity_compartment.this : k => v.id }
}

output "compartments" {
  description = "Created compartments keyed by name (curated fields, not the raw provider object)"
  value = {
    for k, v in oci_identity_compartment.this : k => {
      id            = v.id
      name          = v.name
      description   = v.description
      parent_id     = v.compartment_id
      enable_delete = v.enable_delete
      state         = v.state
      time_created  = v.time_created
    }
  }
}

################################################################################
# Groups
################################################################################

output "group_ids" {
  description = "Map of group name => OCID for every created group"
  value       = { for k, v in oci_identity_group.this : k => v.id }
}

output "groups" {
  description = "Created groups keyed by name (curated fields, not the raw provider object)"
  value = {
    for k, v in oci_identity_group.this : k => {
      id           = v.id
      name         = v.name
      description  = v.description
      state        = v.state
      time_created = v.time_created
    }
  }
}

output "group_memberships" {
  description = "Map of group name => list of member user OCIDs, derived from the created oci_identity_user_group_membership resources (proves the memberships exist, not just that they were requested)"
  value = {
    for group_name, group in oci_identity_group.this : group_name => [
      for m in oci_identity_user_group_membership.this : m.user_id
      if m.group_id == group.id
    ]
  }
}

################################################################################
# Dynamic Groups
################################################################################

output "dynamic_group_ids" {
  description = "Map of dynamic group name => OCID for every created dynamic group"
  value       = { for k, v in oci_identity_dynamic_group.this : k => v.id }
}

output "dynamic_groups" {
  description = "Created dynamic groups keyed by name (curated fields, not the raw provider object)"
  value = {
    for k, v in oci_identity_dynamic_group.this : k => {
      id            = v.id
      name          = v.name
      description   = v.description
      matching_rule = v.matching_rule
      state         = v.state
      time_created  = v.time_created
    }
  }
}

################################################################################
# Policies
################################################################################

output "policy_ids" {
  description = "Map of policy name => OCID for every created policy"
  value       = { for k, v in oci_identity_policy.this : k => v.id }
}

output "policies" {
  description = "Created policies keyed by name, including the resolved statements (curated fields, not the raw provider object)"
  value = {
    for k, v in oci_identity_policy.this : k => {
      id             = v.id
      name           = v.name
      description    = v.description
      compartment_id = v.compartment_id
      statements     = v.statements
      version_date   = v.version_date
      state          = v.state
      time_created   = v.time_created
    }
  }
}
