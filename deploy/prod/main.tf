terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

locals {
  namespace     = var.namespace
  backend_host  = var.backend_host
  frontend_host = var.frontend_host

  backend_env = {
    RAILS_ENV                = "production"
    RACK_ENV                 = "production"
    PORT                     = tostring(var.backend_service_port)
    RAILS_LOG_TO_STDOUT      = "true"
    RAILS_SERVE_STATIC_FILES = "true"
    API_URL                  = "https://${local.backend_host}"
    FRONTEND_URL             = "https://${local.frontend_host}"
    ACTIVE_STORAGE_ROOT      = "/var/pv/messy-data/storage"
    POSTHOG_KEY              = var.posthog_key
    POSTHOG_HOST             = var.posthog_host
  }
}

resource "kubernetes_namespace" "env" {
  metadata {
    name = local.namespace
  }
}

# Backend API (puma only)
module "backend" {
  source       = "../modules/backend"
  namespace    = local.namespace
  env_name     = var.environment
  name         = "backend"
  image        = var.backend_image
  replicas     = var.backend_replicas
  service_port = var.backend_service_port
  command      = ["bash", "-c", "bundle exec rails db:prepare && bundle exec puma -C config/puma.rb"]
  config_env   = local.backend_env
  secret_env   = var.backend_secret_env
  image_pull_secret_name = var.image_pull_secret_name
  storage_mount_path     = "/var/pv/messy-data"
  depends_on   = [kubernetes_namespace.env]
}

# Solid Queue worker (same image as backend, different command)
module "worker" {
  source                 = "../modules/worker"
  namespace              = local.namespace
  env_name               = var.environment
  name                   = "worker"
  image                  = var.backend_image
  replicas               = 1
  command                = ["bash", "-c", "bundle exec rails db:prepare && bundle exec rake solid_queue:start"]
  config_env             = local.backend_env
  secret_env             = var.backend_secret_env
  image_pull_secret_name = var.image_pull_secret_name
  storage_claim_name     = module.backend.storage_claim_name
  storage_mount_path     = "/var/pv/messy-data"
  depends_on             = [module.backend]
}

# Frontend SPA
module "frontend" {
  source                 = "../modules/frontend"
  namespace              = local.namespace
  env_name               = var.environment
  name                   = "frontend"
  image                  = var.frontend_image
  replicas               = var.frontend_replicas
  service_port           = var.frontend_service_port
  config_env = {
    MESSY_API_URL      = "https://${local.backend_host}"
    POSTHOG_KEY        = var.posthog_key
    POSTHOG_HOST       = var.posthog_host
    TURNSTILE_SITE_KEY = var.turnstile_site_key
  }
  image_pull_secret_name = var.image_pull_secret_name
  depends_on             = [kubernetes_namespace.env]
}

# Ingress for both frontend and backend
module "ingress" {
  source          = "../modules/ingress"
  namespace       = local.namespace
  name            = "messy"
  class_name      = var.ingress_class_name
  tls_secret_name = var.tls_secret_name
  annotations = {
    "nginx.ingress.kubernetes.io/proxy-body-size"    = "64m"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"  = "3600"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"  = "3600"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "3600"
  }
  rules = [
    {
      host         = local.frontend_host
      service_name = module.frontend.service_name
      service_port = module.frontend.service_port
      path         = "/"
    },
    {
      host         = local.backend_host
      service_name = module.backend.service_name
      service_port = module.backend.service_port
      path         = "/"
    },
    {
      # Catch-all: any custom tracking domain (a CNAME pointed at the backend
      # host) routes to the backend. Tracking endpoints are token-signed and
      # host-agnostic, so no per-domain ingress rule is needed.
      host         = ""
      service_name = module.backend.service_name
      service_port = module.backend.service_port
      path         = "/"
    }
  ]
  depends_on = [module.frontend, module.backend]
}
