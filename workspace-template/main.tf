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
    sudo apt-get install -y python3.12 python3.12-venv python3.12-dev openjdk-17-jdk-headless
    # Set JAVA_HOME for PySpark
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /home/coder/.bashrc
    echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> /home/coder/.bashrc
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

resource "coder_script" "spark_session" {
  agent_id           = coder_agent.main.id
  display_name       = "Spark session helper"
  icon               = "/icon/python.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/bin/bash
    set -e
    cat > /home/coder/spark_session.py << 'PYEOF'
import glob
import socket

from pyspark.sql import SparkSession

JARS_DIR = "/opt/spark/jars"


def create_spark_session(app_name: str = "DPM") -> SparkSession:
    """
    Creates a SparkSession from a Coder workspace connecting remotely to:
      - Spark cluster    : spark://spark-master:7077
      - Hive Metastore   : thrift://hive-metastore:9083
      - MinIO (S3)       : http://minio:9000
      - Iceberg catalogs : spark_catalog (Hive-backed) + local (filesystem)

    JARs are pre-downloaded to ~/jars/ by the workspace startup script.
    """
    jars = ",".join(glob.glob(f"{JARS_DIR}/*.jar"))

    return (
        SparkSession.builder
        .appName(app_name)
        .master("spark://spark-master:7077")

        # ── Remote driver config ──────────────────────────────────────────────
        # Workers need to connect back to the driver (this workspace container).
        .config("spark.driver.host",        socket.gethostname())
        .config("spark.driver.bindAddress", "0.0.0.0")

        # ── Pre-downloaded JARs ───────────────────────────────────────────────
        .config("spark.jars", jars)

        # ── Hive Metastore ────────────────────────────────────────────────────
        .config("hive.metastore.uris", "thrift://hive-metastore:9083")

        # ── MinIO / S3 ────────────────────────────────────────────────────────
        .config("spark.hadoop.fs.s3a.endpoint",          "http://minio:9000")
        .config("spark.hadoop.fs.s3a.access.key",        "minioadmin")
        .config("spark.hadoop.fs.s3a.secret.key",        "minioadmin")
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl",
                "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.hadoop.fs.s3a.aws.credentials.provider",
                "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
        .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")

        # ── Iceberg extensions ────────────────────────────────────────────────
        .config("spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")

        # Hive-backed catalog (persistent, shared with Trino)
        .config("spark.sql.catalog.spark_catalog",
                "org.apache.iceberg.spark.SparkSessionCatalog")
        .config("spark.sql.catalog.spark_catalog.type", "hive")

        # Filesystem-backed catalog
        .config("spark.sql.catalog.local",
                "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.local.type",      "hadoop")
        .config("spark.sql.catalog.local.warehouse", "s3a://bronze/iceberg")

        .config("spark.sql.defaultCatalog", "spark_catalog")
        .enableHiveSupport()
        .getOrCreate()
    )
PYEOF
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
  image = "coder-workspace:latest"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  command = ["sh", "-c", coder_agent.main.init_script]

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  networks_advanced {
    name = data.docker_network.dpm.name
  }

}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-home"

  lifecycle {
    prevent_destroy = true
  }
}
