terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Build the Coder server image
resource "docker_image" "coder" {
  name = "${var.image_name}:${var.image_tag}"

  build {
    context    = "${path.module}/app"
    dockerfile = "Dockerfile"

    label = {
      "managed-by" = "terraform"
      "version"    = var.image_tag
    }
  }

  triggers = {
    dockerfile = filesha256("${path.module}/app/Dockerfile")
    entrypoint = filesha256("${path.module}/app/docker-entrypoint.sh")
  }
}

# Persistent volume for Coder data
resource "docker_volume" "coder_data" {
  name = "coder-data"

  lifecycle {
    prevent_destroy = true
  }
}

# Run the Coder server container
resource "docker_container" "coder" {
  name  = var.container_name
  image = docker_image.coder.image_id

  ports {
    internal = 3000
    external = var.host_port
  }

  env = [
    "CODER_ACCESS_URL=http://host.docker.internal:${var.host_port}",
    "CODER_HTTP_ADDRESS=0.0.0.0:3000",
    "CODER_FIRST_USER_EMAIL=${var.admin_email}",
    "CODER_FIRST_USER_USERNAME=${var.admin_username}",
    "CODER_FIRST_USER_PASSWORD=${var.admin_password}",
    "CODER_FIRST_USER_TRIAL=false",
  ]

  volumes {
    volume_name    = docker_volume.coder_data.name
    container_path = "/home/coder/.config/coderv2"
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  restart = "unless-stopped"

  labels {
    label = "managed-by"
    value = "terraform"
  }
}
