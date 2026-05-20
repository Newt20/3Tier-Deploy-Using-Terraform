output "vpc_id" {
  value = module.network.vpc_id
}

output "frontend_public_ip" {
  description = "Open this in your browser: http://<this-ip>"
  value       = module.compute.frontend_public_ip
}

output "frontend_url" {
  description = "Direct URL to the Team Directory app"
  value       = "http://${module.compute.frontend_public_ip}"
}

output "bastion_public_ip" {
  description = "SSH jump host"
  value       = module.compute.bastion_public_ip
}

output "backend_private_ip" {
  description = "Backend API — only reachable from within VPC"
  value       = module.compute.backend_private_ip
}

output "db_endpoint" {
  description = "RDS endpoint — injected into backend .env automatically"
  value       = module.compute.db_endpoint
  sensitive   = true
}

output "nat_gateway_ip" {
  value = module.network.nat_gateway_ip
}

# ─── Handy SSH commands ───────────────────────────────────────

output "cmd_ssh_bastion" {
  value = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.compute.bastion_public_ip}"
}

output "cmd_ssh_backend" {
  value = "ssh -J ubuntu@${module.compute.bastion_public_ip} ubuntu@${module.compute.backend_private_ip} -i ~/.ssh/${var.key_name}.pem"
}

output "cmd_test_api" {
  description = "Run from inside VPC or via bastion to test the API directly"
  value       = "curl http://${module.compute.backend_private_ip}:8080/api/members"
}
