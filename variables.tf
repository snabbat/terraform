variable "image_name" {
  description = "Name for the Docker image"
  type        = string
  default     = "my-app"
}

variable "image_tag" {
  description = "Tag for the Docker image"
  type        = string
  default     = "latest"
}

variable "container_name" {
  description = "Name for the Docker container"
  type        = string
  default     = "my-app-container"
}

variable "host_port" {
  description = "Host port to map to container port 80"
  type        = number
  default     = 8080
}
