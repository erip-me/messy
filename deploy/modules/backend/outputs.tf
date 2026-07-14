output "service_name" {
  value = kubernetes_service.this.metadata[0].name
}

output "service_port" {
  value = kubernetes_service.this.spec[0].port[0].port
}

output "deployment_name" {
  value = kubernetes_deployment.this.metadata[0].name
}

output "storage_claim_name" {
  value = var.storage_mount_path != null ? kubernetes_persistent_volume_claim.storage[0].metadata[0].name : null
}
