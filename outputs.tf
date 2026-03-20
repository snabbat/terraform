output "image_id" {
  description = "ID of the built Coder image"
  value       = docker_image.coder.image_id
}

output "image_name" {
  description = "Full name of the built Coder image"
  value       = docker_image.coder.name
}

output "container_id" {
  description = "ID of the running Coder container"
  value       = docker_container.coder.id
}

output "coder_url" {
  description = "URL to access the Coder server"
  value       = "http://localhost:${var.host_port}"
}
