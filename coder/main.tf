terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "coder" {}
provider "docker" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Read API key from host environment variable
variable "anthropic_api_key" {
  type        = string
  description = "Anthropic API key, sourced from TF_VAR_anthropic_api_key env var on the host"
  sensitive   = true
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    # Authenticate with Coder using the agent token from env
    coder login ${data.coder_workspace.me.access_url} --token $CODER_AGENT_TOKEN

    # Verify claude code is available
    claude --version
  EOT

  metadata {
    display_name = "Claude Code Version"
    key          = "claude-version"
    script       = "claude --version 2>&1 || echo 'not installed'"
    interval     = 86400
  }
}

# Build the custom Docker image
resource "docker_image" "workspace" {
  name = "coder-workspace:latest"
  build {
    context = "./build"
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.workspace.image_id
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname = data.coder_workspace.me.name

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "ANTHROPIC_API_KEY=${var.anthropic_api_key}",
  ]

  entrypoint = ["sh", "-c", coder_agent.main.init_script]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-home"

  lifecycle {
    ignore_changes = all
  }
}

resource "coder_metadata" "container" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id

  item {
    key   = "image"
    value = "coder-workspace:latest"
  }
}
