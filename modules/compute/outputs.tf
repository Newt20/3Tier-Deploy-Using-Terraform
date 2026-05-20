output "bastion_public_ip"   { value = aws_instance.nt-bastion.public_ip }
output "frontend_public_ip"  { value = aws_instance.nt-frontend.public_ip }
output "frontend_public_dns" { value = aws_instance.nt-frontend.public_dns }
output "backend_private_ip"  { value = aws_instance.nt-backend.private_ip }
output "db_endpoint" {
  description = "Hostname:port — use as DB_HOST in backend"
  value       = aws_instance.nt-db-server.private_ip
}
