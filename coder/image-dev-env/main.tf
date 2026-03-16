terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "coder" {}

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces. A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in."
}

provider "kubernetes" {
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "The number of CPU cores"
  default      = "2"
  icon         = "/icon/memory.svg"
  mutable      = true

  option {
    name  = "2 Cores"
    value = "2"
  }
  option {
    name  = "4 Cores"
    value = "4"
  }
  option {
    name  = "6 Cores"
    value = "6"
  }
  option {
    name  = "8 Cores"
    value = "8"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "The amount of memory in GB"
  default      = "2"
  icon         = "/icon/memory.svg"
  mutable      = true

  option {
    name  = "2 GB"
    value = "2"
  }
  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "6 GB"
    value = "6"
  }
  option {
    name  = "8 GB"
    value = "8"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  default      = "10"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false

  validation {
    min = 1
    max = 99999
  }
}

data "coder_parameter" "repo_source_preset" {
  name         = "repo_source"
  display_name = "Repository source"
  description  = "Git forge to clone from on first start"
  type         = "string"
  default      = "forgejo_self"
  mutable      = true

  option {
    name  = "GitHub (self)"
    value = "github_self"
  }

  option {
    name  = "Forgejo (self)"
    value = "forgejo_self"
  }

  option {
    name  = "Custom"
    value = "custom"
  }
}

data "coder_parameter" "repo_source_custom" {
  count        = data.coder_parameter.repo_source_preset.value == "custom" ? 1 : 0
  name         = "repo_source_custom"
  display_name = "Custom repository source"
  description  = "Example: https://github.com/someuser/"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "repo_name" {
  name         = "repo_name"
  display_name = "Repository name"
  description  = "Name of the repo to clone on first start"
  type         = "string"
  default      = "coder-images"
  mutable      = true
}

data "coder_parameter" "repo_ref" {
  name         = "repo_ref"
  display_name = "Repository branch/tag"
  description  = "Optional ref to checkout"
  type         = "string"
  default      = ""
  mutable      = true
}

locals {
  repo_source = (
    data.coder_parameter.repo_source_preset.value == "forgejo_self" ? "https://git.sylvainleclercq.com/depassage/" :
    data.coder_parameter.repo_source_preset.value == "github_self"  ? "https://github.com/de-passage/" :
    try(data.coder_parameter.repo_source_custom[0].value, "")
  )

  workspace_folder = (
    data.coder_parameter.repo_name.value != "" ?
    "/home/dev/workspace/${data.coder_parameter.repo_name.value}" :
    "/home/dev/workspace"
  )
}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = local.workspace_folder

  startup_script = <<-EOT
    set -e

    if [ ! -x /tmp/code-server/bin/code-server ]; then
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
    fi

    git config --global credential.helper store
    mkdir -p "$HOME/workspace"

    if [ -n "$${FORGEJO_GIT_USERNAME:-}" ] && [ -n "$${FORGEJO_GIT_TOKEN:-}" ]  && [ "${data.coder_parameter.repo_source_preset.value}" = forgejo_self ]; then
      echo "Approving credentials"
      printf "protocol=https\nhost=git.sylvainleclercq.com\nusername=%s\npassword=%s\n" "$${FORGEJO_GIT_USERNAME}" "$${FORGEJO_GIT_TOKEN}" | git credential approve
    else
      echo "Something is wrong: ${data.coder_parameter.repo_source_preset.value} $${FORGEJO_GIT_TOKEN} $${FORGEJO_GIT_USERNAME}"
    fi

    REPO_SOURCE='${local.repo_source}'
    REPO_NAME='${data.coder_parameter.repo_name.value}'
    REPO_REF='${data.coder_parameter.repo_ref.value}'

    if [ -n "$REPO_SOURCE" ] && [ -n "$REPO_NAME" ]; then
      TARGET_DIR="$HOME/workspace/$REPO_NAME"
      REPO_URL="$REPO_SOURCE/$REPO_NAME.git"

      if [ ! -d "$TARGET_DIR/.git" ]; then
        git clone "$REPO_URL" "$TARGET_DIR"
        if [ -n "$REPO_REF" ]; then
          cd "$TARGET_DIR"
          git checkout "$REPO_REF"
        fi
      fi
    fi

    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=${local.workspace_folder}"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }

    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "main" {
  count = data.coder_workspace.me.start_count

  depends_on = [
    kubernetes_persistent_volume_claim_v1.home
  ]

  wait_for_rollout = false

  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }

    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        "com.coder.workspace.id"     = data.coder_workspace.me.id
        "com.coder.workspace.name"   = data.coder_workspace.me.name
        "com.coder.user.id"          = data.coder_workspace_owner.me.id
        "com.coder.user.username"    = data.coder_workspace_owner.me.name
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
          "app.kubernetes.io/part-of"  = "coder"
          "com.coder.resource"         = "true"
          "com.coder.workspace.id"     = data.coder_workspace.me.id
          "com.coder.workspace.name"   = data.coder_workspace.me.name
          "com.coder.user.id"          = data.coder_workspace_owner.me.id
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }

      spec {
        node_selector = {
          workload = "workspaces"
        }

        hostname = lower(replace(data.coder_workspace.me.name, "_", "-"))

        toleration {
          key      = "workload"
          operator = "Equal"
          value    = "workspaces"
          effect   = "NoSchedule"
        }

        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true
          supplemental_groups = [ 994 ]
        }

        image_pull_secrets {
          name = "forgejo-registry-pull-secret"
        }

        container {
          name              = "dev"
          image             = "git.sylvainleclercq.com/depassage/coder-docker:nightly"
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]

          security_context {
            run_as_user = "1000"
          }

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          env {
            name  = "DOCKER_HOST"
            value = "unix:///var/run/docker.sock"
          }

          env {
            name = "FORGEJO_GIT_USERNAME"
            value_from {
              secret_key_ref {
                name = "forgejo-git-auth"
                key  = "username"
              }
            }
          }

          env {
            name = "FORGEJO_GIT_TOKEN"
            value_from {
              secret_key_ref {
                name = "forgejo-git-auth"
                key  = "token"
              }
            }
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }

          volume_mount {
            mount_path = "/home/dev/workspace"
            name       = "home"
            read_only  = false
          }

          volume_mount {
            mount_path = "/var/run/docker.sock"
            name       = "docker-sock"
            read_only  = false
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata.0.name
            read_only  = false
          }
        }

        volume {
          name = "docker-sock"
          host_path {
            path = "/var/run/docker.sock"
            type = "Socket"
          }
        }

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
