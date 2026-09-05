module "wrapper" {
  source = "../"

  for_each = var.items

  compartment_id = try(each.value.compartment_id, var.defaults.compartment_id, null)
  compartments   = try(each.value.compartments, var.defaults.compartments, {})
  create         = try(each.value.create, var.defaults.create, true)
  defined_tags   = try(each.value.defined_tags, var.defaults.defined_tags, {})
  dynamic_groups = try(each.value.dynamic_groups, var.defaults.dynamic_groups, {})
  groups         = try(each.value.groups, var.defaults.groups, {})
  policies       = try(each.value.policies, var.defaults.policies, {})
  tags           = try(each.value.tags, var.defaults.tags, {})
  tenancy_id     = try(each.value.tenancy_id, var.defaults.tenancy_id)
}
