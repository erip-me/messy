variable "namespace" {
  type = string
}

variable "name" {
  type    = string
  default = "frontend"
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

variable "service_port" {
  type    = number
  default = 5000
}

variable "image_pull_secret_name" {
  type    = string
  default = null
}

variable "config_env" {
  type    = map(string)
  default = {}
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
