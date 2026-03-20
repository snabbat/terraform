output "image_id" {
  description = "ID of the built Docker image"
  value       = docker_image.app.image_id
}

output "image_name" {
  description = "Full name of the built Docker image"
  value       = docker_image.app.name
}

output "container_id" {
  description = "ID of the running container"
  value       = docker_container.app.id
}

output "app_url" {
  description = "URL to access the running app"
  value       = "http://localhost:${var.host_port}"
}
