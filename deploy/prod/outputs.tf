output "frontend_url" {
  value = "https://${var.frontend_host}"
}

output "backend_url" {
  value = "https://${var.backend_host}"
}

output "backend_service_name" {
  value = module.backend.service_name
}

output "frontend_service_name" {
  value = module.frontend.service_name
}
