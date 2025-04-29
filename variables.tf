variable "prefix" {
  type        = string
  default     = "tfvmex"
  description = "Prefix for all resource names"
}

variable "location" {
  type        = string
  default     = "West Europe"
  description = "Azure region to deploy resources"
}

variable "vm_count" {
  type        = number
  default     = 2
  description = "Number of virtual machines to create"
}