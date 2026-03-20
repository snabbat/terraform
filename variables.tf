variable "image_name" {
  description = "Name for the Coder Docker image"
  type        = string
  default     = "coder-server"
}

variable "image_tag" {
  description = "Tag for the Docker image"
  type        = string
  default     = "latest"
}

variable "container_name" {
  description = "Name for the Coder container"
  type        = string
  default     = "coder-server"
}

variable "host_port" {
  description = "Host port to map to Coder's internal port 3000"
  type        = number
  default     = 3000
}

variable "admin_email" {
  description = "Email for the Coder admin user"
  type        = string
  default     = "nabbat.soufiane@gmail.com"
}

variable "admin_username" {
  description = "Username for the Coder admin user"
  type        = string
  default     = "snabbat"
}

variable "admin_password" {
  description = "Password for the Coder admin user"
  type        = string
  default     = "C0d3r-S3rv3r-2026!@#"
  sensitive   = true
}
