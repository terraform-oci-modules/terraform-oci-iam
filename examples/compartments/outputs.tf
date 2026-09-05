output "root_compartment_id" {
  description = "OCID of the top-level compartment"
  value       = module.root.compartment_ids["ex-compartments"]
}

output "environment_compartment_ids" {
  description = "Map of environment compartment name => OCID"
  value       = module.environments.compartment_ids
}

output "team_compartment_ids" {
  description = "Map of team compartment name => OCID"
  value       = module.teams.compartment_ids
}
