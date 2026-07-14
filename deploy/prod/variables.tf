variable "environment" {
  type    = string
  default = "production"
}

variable "namespace" {
  type    = string
  default = "messy"
}

variable "kubeconfig_path" {
  type    = string
  default = "./kubeconfig.yaml"
}

variable "kubeconfig_context" {
  type        = string
  description = "Kubeconfig context name that points at the target cluster."
}

variable "backend_host" {
  type        = string
  description = "Public hostname for the API, e.g. api.example.com."
}

variable "frontend_host" {
  type        = string
  description = "Public hostname for the web app, e.g. app.example.com."
}

variable "ingress_class_name" {
  type    = string
  default = "nginx"
}

variable "tls_secret_name" {
  type        = string
  default     = null
  description = "Pre-created TLS secret for the ingress; null when TLS terminates upstream."
}

variable "backend_image" {
  type        = string
  description = "Backend image, built from backend/ and pushed to your registry."
}

variable "frontend_image" {
  type        = string
  description = "Frontend image, built from frontend/ and pushed to your registry."
}

variable "backend_replicas" {
  type    = number
  default = 1
}

variable "frontend_replicas" {
  type    = number
  default = 1
}

variable "backend_service_port" {
  type    = number
  default = 5000
}

variable "frontend_service_port" {
  type    = number
  default = 5000
}

variable "backend_secret_env" {
  type      = map(string)
  sensitive = true
}

variable "image_pull_secret_name" {
  type        = string
  default     = null
  description = "Pull secret for a private registry; null for public images."
}

variable "posthog_key" {
  description = "PostHog project API key for the frontend (public-facing). Empty disables analytics."
  type        = string
  default     = ""
}

variable "posthog_host" {
  description = "PostHog ingestion host for the frontend."
  type        = string
  default     = "https://eu.i.posthog.com"
}

variable "turnstile_site_key" {
  description = "Cloudflare Turnstile site key for the signup form (public-facing). Empty disables the captcha."
  type        = string
  default     = ""
}
