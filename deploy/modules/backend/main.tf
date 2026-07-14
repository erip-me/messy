locals {
  labels = {
    app       = var.name
    component = "backend"
    tier      = "api"
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

resource "kubernetes_persistent_volume" "storage" {
  count = var.storage_mount_path != null ? 1 : 0

  metadata {
    name = "${var.namespace}-${var.name}-storage"
  }

  spec {
    capacity = {
      storage = var.storage_size
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      host_path {
        path = var.storage_mount_path
        type = "DirectoryOrCreate"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "storage" {
  count = var.storage_mount_path != null ? 1 : 0

  metadata {
    name      = "${var.name}-storage"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteMany"]
    volume_name  = kubernetes_persistent_volume.storage[0].metadata[0].name
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    # Zero-downtime rollouts: bring a new, healthy pod up before removing the old
    # one (never drop below the desired count), so image/API requests aren't
    # dropped during a redeploy.
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = 0
        max_surge       = 1
      }
    }

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        # Run as the image's non-root user (uid 1000). The ActiveStorage
        # hostPath volume (/var/pv/messy-data) is chowned to 1000:1000 on the
        # node, so uploads are writable without root.
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

          port {
            container_port = var.service_port
            name           = "http"
          }

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

          # Gate the slow boot (db:prepare + puma) so liveness/readiness don't
          # trip during startup. ~200s budget.
          startup_probe {
            http_get {
              path = "/up"
              port = "http"
            }
            period_seconds    = 5
            failure_threshold = 40
            timeout_seconds   = 3
          }

          # Only receive traffic (and count as "available" for the rollout) once
          # Rails answers — this is what makes the rolling update zero-downtime.
          readiness_probe {
            http_get {
              path = "/up"
              port = "http"
            }
            period_seconds    = 10
            timeout_seconds   = 3
            failure_threshold = 3
          }

          # Restart a wedged pod (active only after startup_probe succeeds).
          liveness_probe {
            http_get {
              path = "/up"
              port = "http"
            }
            period_seconds    = 15
            timeout_seconds   = 3
            failure_threshold = 4
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
          for_each = var.storage_mount_path != null ? [var.storage_mount_path] : []
          content {
            name = "storage"
            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim.storage[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      port        = var.service_port
      target_port = "http"
    }
  }
}
