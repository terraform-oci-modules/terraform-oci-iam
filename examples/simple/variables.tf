variable "tenancy_id" {
  description = "The OCID of the tenancy (root compartment)"
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment to create the example compartment under and attach the policy to. Defaults to the tenancy root when null"
  type        = string
  default     = null
}
