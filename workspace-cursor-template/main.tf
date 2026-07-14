terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.23"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "coder" {}
provider "docker" {}

data "docker_network" "dpm" {
  name = "plateforme_dpm-network"
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
}

# Cursor runs as a KasmVNC desktop inside the workspace image. The image bakes
# an nginx proxy on :6902 that fronts KasmVNC's self-signed HTTPS/basic-auth on
# :6901, so Coder can proxy the app over plain loopback HTTP.
# KasmVNC hard-codes its websocket to the site root (/websockify), which breaks
# under Coder's path-based app proxy. So we expose the workspace's internal
# nginx proxy on a published host port and surface it as an external app button
# that opens it directly (websockets then work, same as the validated standalone).
resource "coder_app" "cursor" {
  agent_id     = coder_agent.main.id
  slug         = "cursor"
  display_name = "Cursor"
  url          = "http://localhost:7900"
  icon         = "/icon/cursor.svg"
  external     = true
}

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  name     = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  image    = "coder-cursor:latest"
  shm_size = 1024 # MiB — Cursor/Electron/Chromium need shared memory

  # The Kasm entrypoint stays intact; the baked custom_startup.sh reads these to
  # launch the Coder agent alongside the desktop. Init script is base64-encoded
  # so its newlines survive as a Docker env value.
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_AGENT_INIT_B64=${base64encode(coder_agent.main.init_script)}",
  ]

  # Publish the internal nginx proxy (6902) so the browser can reach KasmVNC
  # directly, bypassing Coder's path proxy (which KasmVNC's absolute websocket
  # path is incompatible with). NOTE: single fixed host port — one workspace.
  ports {
    internal = 6902
    external = 7900
  }

  volumes {
    container_path = "/home/kasm-user/projects"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  networks_advanced {
    name = data.docker_network.dpm.name
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-projects"
}
