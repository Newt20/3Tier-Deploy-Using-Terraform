output "vpc_id"             { value = aws_vpc.nt-vpc.id }
output "public_subnet_ids"  { value = aws_subnet.nt-public[*].id }
output "private_subnet_ids" { value = aws_subnet.nt-private-app[*].id }
output "db_subnet_ids"      { value = aws_subnet.nt-private-db[*].id }
output "nat_gateway_ip"     { value = aws_eip.nt-nat-eip.public_ip }
