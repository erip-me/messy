variable "namespace" {
  type = string
}

variable "name" {
  type    = string
  default = "worker"
}

variable "env_name" {
  type = string
}

variable "image" {
  type = string
}

variable "replicas" {
  type    = number
  default = 1
}

variable "command" {
  type    = list(string)
  default = ["bash", "-c", "bundle exec rails db:prepare && bundle exec rake solid_queue:start"]
}

variable "config_env" {
  type    = map(string)
  default = {}
}

variable "secret_env" {
  type      = map(string)
  default   = {}
  sensitive = true
}

variable "image_pull_secret_name" {
  type    = string
  default = null
}

variable "storage_claim_name" {
  type    = string
  default = null
}

variable "storage_mount_path" {
  type    = string
  default = null
}

variable "resources" {
  type = object({
    limits = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
    requests = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
  })
  default = {}
}
