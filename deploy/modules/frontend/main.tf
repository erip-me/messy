locals {
  labels = {
    app       = var.name
    component = "frontend"
    tier      = "web"
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

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
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

          port {
            container_port = var.service_port
            name           = "http"
          }

          dynamic "env" {
            for_each = var.config_env
            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            limits   = try(var.resources.limits, null)
            requests = try(var.resources.requests, null)
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
