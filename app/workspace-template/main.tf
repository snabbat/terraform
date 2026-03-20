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

locals {
  packages = join(" ", [
    for line in split("\n", file("${path.module}/requirements.txt")) :
    "\"${trimspace(line)}\""
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ])
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
}

resource "coder_script" "code_server" {
  agent_id           = coder_agent.main.id
  display_name       = "code-server"
  icon               = "/icon/code.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/bin/bash
    set -e
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 > /tmp/code-server.log 2>&1 &
  EOT
}

resource "coder_script" "python" {
  agent_id           = coder_agent.main.id
  display_name       = "Python 3.12"
  icon               = "/icon/python.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/bin/bash
    set -e
    # Install Python 3.12
    sudo apt-get update -q
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update -q
    sudo apt-get install -y python3.12 python3.12-venv python3.12-dev
    # Set python3.12 as default
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1
    # Create a virtualenv at ~/venv and install packages
    python3.12 -m venv --clear /home/coder/venv
    /home/coder/venv/bin/pip install --upgrade pip
    /home/coder/venv/bin/pip install ${local.packages}
    # Add venv to PATH permanently
    echo 'export PATH="/home/coder/venv/bin:$PATH"' >> /home/coder/.bashrc
  EOT
}

resource "coder_app" "code_server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  name  = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  image = "codercom/enterprise-base:ubuntu"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  command = ["sh", "-c", coder_agent.main.init_script]

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-home"

  lifecycle {
    prevent_destroy = true
  }
}
