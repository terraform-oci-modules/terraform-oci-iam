variable "tenancy_id" {
  description = "The OCID of the tenancy (root compartment)"
  type        = string
}

variable "compartment_id" {
  description = "The OCID of the compartment whose instances and functions the dynamic groups should match, and where the policies are attached"
  type        = string
}
