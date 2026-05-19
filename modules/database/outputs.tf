output "db_endpoint" {
  description = "Hostname:port — use as DB_HOST in backend"
  value       = aws_db_instance.nt-rds.endpoint
  sensitive   = true
}

output "db_port" {
  value = aws_db_instance.nt-rds.port
}

output "db_identifier" {
  value = aws_db_instance.nt-rds.identifier
}
