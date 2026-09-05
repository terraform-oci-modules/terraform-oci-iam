variable "tenancy_id" {
  description = "The OCID of the tenancy (root compartment)"
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment to build the example hierarchy under and attach compartment-scoped policies to. Defaults to the tenancy root when null"
  type        = string
  default     = null
}

variable "group_member_user_ids" {
  description = "Optional list of existing user OCIDs to add to the platform-admins group. Left empty by default so the example applies cleanly in any tenancy"
  type        = list(string)
  default     = []
}
