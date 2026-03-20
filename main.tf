terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Build the Docker image from the local Dockerfile
resource "docker_image" "app" {
  name = "${var.image_name}:${var.image_tag}"

  build {
    context    = "${path.module}/app"
    dockerfile = "Dockerfile"

    label = {
      "managed-by" = "terraform"
      "version"    = var.image_tag
    }
  }

  # Rebuild image when Dockerfile or app files change
  triggers = {
    dockerfile = filesha256("${path.module}/app/Dockerfile")
    html       = filesha256("${path.module}/app/index.html")
  }
}

# Run a container from the built image
resource "docker_container" "app" {
  name  = var.container_name
  image = docker_image.app.image_id

  ports {
    internal = 80
    external = var.host_port
  }

  restart = "unless-stopped"

  labels {
    label = "managed-by"
    value = "terraform"
  }
}
