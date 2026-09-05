output "compartment_ids" {
  description = "Map of compartment name => OCID"
  value       = module.iam.compartment_ids
}

output "group_ids" {
  description = "Map of group name => OCID"
  value       = module.iam.group_ids
}

output "group_memberships" {
  description = "Map of group name => member user OCIDs"
  value       = module.iam.group_memberships
}

output "dynamic_group_ids" {
  description = "Map of dynamic group name => OCID"
  value       = module.iam.dynamic_group_ids
}

output "policy_ids" {
  description = "Map of policy name => OCID"
  value       = module.iam.policy_ids
}
