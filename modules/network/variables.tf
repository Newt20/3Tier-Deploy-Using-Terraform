variable "project_name" {
  type        = string
  description = "Project name prefix"
}
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "db_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
