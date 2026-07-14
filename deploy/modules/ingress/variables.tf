variable "namespace" {
  type = string
}

variable "name" {
  type = string
}

variable "class_name" {
  type    = string
  default = "nginx"
}

variable "annotations" {
  type    = map(string)
  default = {}
}

variable "tls_secret_name" {
  type        = string
  default     = null
  description = "Secret that stores the TLS certificate. Set to null to disable TLS."
}

variable "rules" {
  type = list(object({
    host         = string
    service_name = string
    service_port = number
    path         = optional(string, "/")
    path_type    = optional(string, "Prefix")
  }))
}
