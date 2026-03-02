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

variable "github_repo" {
  type        = string
  description = "GitHub repository URL (e.g., https://github.com/owner/repo)"
}

variable "github_token" {
  type        = string
  description = "GitHub runner registration token"
  sensitive   = true
}

variable "runner_labels" {
  type        = string
  description = "Labels for the runner (comma-separated)"
  default     = "linux"
}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    echo "GitHub Actions Runner is starting..."
    echo "Repository: ${var.github_repo}"
    echo "Labels: ${var.runner_labels}"
  EOT

  metadata {
    display_name = "Runner Status"
    key          = "runner-status"
    script       = "echo 'Running'"
    interval     = 60
  }
}

resource "docker_image" "workspace" {
  name = "github-runner:latest"
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
  name  = "github-runner-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname = "${data.coder_workspace.me.name}-runner"

  env = [
    "GITHUB_REPO=${var.github_repo}",
    "GITHUB_TOKEN=${var.github_token}",
    "RUNNER_LABELS=${var.runner_labels}",
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
}

resource "coder_metadata" "container" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id

  item {
    key   = "image"
    value = "github-runner:latest"
  }

  item {
    key   = "github_repo"
    value = var.github_repo
  }

  item {
    key   = "labels"
    value = var.runner_labels
  }
}
