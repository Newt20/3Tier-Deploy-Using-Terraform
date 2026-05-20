# ─────────────────────────────────────────────────────────────
# Locals  (from your original)
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = var.project_name
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ─────────────────────────────────────────────────────────────
# Data Sources
# ─────────────────────────────────────────────────────────────

# 2 AZs — required for RDS subnet group
data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 24.04 LTS — preserved from your original
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# ─────────────────────────────────────────────────────────────
# Modules
# ─────────────────────────────────────────────────────────────

module "network" {
  source = "./modules/network"
  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  db_subnet_cidrs          = var.db_subnet_cidrs
  availability_zones       = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "security" {
  source = "./modules/security"
  project_name     = var.project_name
  vpc_id           = module.network.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  db_port          = var.db_port
}

module "compute" {
  source = "./modules/compute"
  project_name       = var.project_name
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_type
  key_name           = var.key_name
  root_volume_size   = var.root_volume_size
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  db_subnet_ids      = module.network.db_subnet_ids
  public_sg_id       = module.security.public_sg_id
  private_sg_id      = module.security.private_sg_id
  database_sg_id     = module.security.database_sg_id
  db_endpoint        = module.compute.db_endpoint
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  db_port            = var.db_port
  db_instance_class = var.db_instance_class
  allocated_storage = var.allocated_storage

  depends_on = [module.network, module.security]
}
