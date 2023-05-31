variable "eip_allocation_id" {
  description = "The allocation ID of an existing EIP"
  type        = string
}

variable "domain" {
  description = "The domain to deploy on"
}

variable "admin_email" {
  description = "An email for certbot to use."
}
