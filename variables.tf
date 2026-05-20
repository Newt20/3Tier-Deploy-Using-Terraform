
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI named profile"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Prefix applied to all resource names"
  type        = string
  default     = "nt"
}


variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnets — frontend EC2 and bastion live here"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private subnets — backend API EC2"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Isolated DB subnets — RDS needs 2 subnets across different AZs"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "allowed_ssh_cidr" {
  description = "Your machine IP in CIDR form, e.g. 203.0.113.5/32"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  description = "Name of existing EC2 key pair in AWS"
  type        = string
  default = "instance_prac_pem"
}

variable "root_volume_size" {
  type    = number
  default = 20
}

# ─────────────────────────────────────────────────────────────
# Database
# ─────────────────────────────────────────────────────────────


variable "db_instance_class" {
  type    = string
  default = "t3.micro"
}

variable "db_name" {
  type    = string
  default = "teamdb"
}

variable "db_username" {
  type      = string
  default   = "nt_admin"
  sensitive = true
}

variable "db_password" {
  description = "Set via: export TF_VAR_db_password=YourPass — never hardcode"
  type        = string
  sensitive   = true
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "allocated_storage" {
  type    = number
  default = 20
}
