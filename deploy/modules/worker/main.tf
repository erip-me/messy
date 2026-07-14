locals {
  labels = {
    app  = var.name
    tier = "worker"
  }
}

resource "kubernetes_config_map" "env" {
  metadata {
    name      = "${var.name}-config"
    namespace = var.namespace
  }

  data = var.config_env
}

resource "kubernetes_secret" "env" {
  metadata {
    name      = "${var.name}-env"
    namespace = var.namespace
  }

  data = var.secret_env
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        # Run as uid 1000: the worker shares the backend's ActiveStorage
        # hostPath (/var/pv/messy-data), chowned to 1000:1000 on the node.
        # See the note in modules/backend/main.tf.
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        dynamic "image_pull_secrets" {
          for_each = var.image_pull_secret_name == null ? [] : [var.image_pull_secret_name]

          content {
            name = image_pull_secrets.value
          }
        }

        container {
          name              = var.name
          image             = var.image
          image_pull_policy = "Always"
          command           = var.command

          env_from {
            config_map_ref {
              name = kubernetes_config_map.env.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.env.metadata[0].name
            }
          }

          resources {
            limits   = try(var.resources.limits, null)
            requests = try(var.resources.requests, null)
          }

          dynamic "volume_mount" {
            for_each = var.storage_mount_path != null ? [var.storage_mount_path] : []
            content {
              name       = "storage"
              mount_path = volume_mount.value
            }
          }
        }

        dynamic "volume" {
          for_each = var.storage_claim_name != null ? [var.storage_claim_name] : []
          content {
            name = "storage"
            persistent_volume_claim {
              claim_name = volume.value
            }
          }
        }
      }
    }
  }
}
