output "public_sg_id"   { value = aws_security_group.nt-public-sg.id }
output "private_sg_id"  { value = aws_security_group.nt-private-sg.id }
output "database_sg_id" { value = aws_security_group.nt-database-sg.id }
