output "dynamic_group_ids" {
  description = "Map of dynamic group name => OCID"
  value       = module.iam.dynamic_group_ids
}

output "policy_ids" {
  description = "Map of policy name => OCID"
  value       = module.iam.policy_ids
}

output "instance_matching_rule" {
  description = "The matching rule on the instance dynamic group"
  value       = module.iam.dynamic_groups["ex-dyn-groups-instances"].matching_rule
}
