variable "service_account_name" {
  type      = string
  sensitive = true
  default   = "pcc-secret-access"
}

variable "secret_name" {
  type      = string
  sensitive = true
  default   = "PCCSecret"
}

variable "secret_project_id" {
  type      = string
  sensitive = true
}

variable "project_id" {
  type      = string
  sensitive = true
}