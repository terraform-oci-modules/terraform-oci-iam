output "compartment_id" {
  description = "OCID of the created compartment"
  value       = module.iam.compartment_ids["ex-simple"]
}

output "group_id" {
  description = "OCID of the created group"
  value       = module.iam.group_ids["ex-simple-admins"]
}

output "policy_id" {
  description = "OCID of the created policy"
  value       = module.iam.policy_ids["ex-simple-admins"]
}

output "policy_statements" {
  description = "Resolved statements on the created policy"
  value       = module.iam.policies["ex-simple-admins"].statements
}
