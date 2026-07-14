locals {
  # A rule with host = "" is a catch-all (matches any unmatched Host header) and
  # is intentionally excluded from the TLS block: those hosts (customer custom
  # tracking domains) terminate TLS at Cloudflare's edge, and Cloudflare->origin
  # runs in "Full" mode which tolerates the default origin cert.
  hosts = distinct([for rule in var.rules : rule.host if rule.host != ""])
}

resource "kubernetes_ingress_v1" "this" {
  metadata {
    name        = var.name
    namespace   = var.namespace
    annotations = var.annotations
  }

  spec {
    ingress_class_name = var.class_name

    dynamic "tls" {
      for_each = var.tls_secret_name != null ? [1] : []

      content {
        hosts       = local.hosts
        secret_name = var.tls_secret_name
      }
    }

    dynamic "rule" {
      for_each = var.rules

      content {
        host = rule.value.host != "" ? rule.value.host : null

        http {
          path {
            path      = rule.value.path
            path_type = rule.value.path_type

            backend {
              service {
                name = rule.value.service_name

                port {
                  number = rule.value.service_port
                }
              }
            }
          }
        }
      }
    }
  }
}
