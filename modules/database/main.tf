# ─── RDS Subnet Group ─────────────────────────────────────────
# RDS REQUIRES subnets in 2 different AZs — this is mandatory

resource "aws_db_subnet_group" "nt-db-subnet-group" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for ${var.project_name} RDS"
  subnet_ids  = var.db_subnet_ids

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# ─── RDS Parameter Group ──────────────────────────────────────
# utf8mb4 = full Unicode including emoji support

resource "aws_db_parameter_group" "nt-db-params" {
  name   = "${var.project_name}-db-params"
  family = "${var.db_engine}${var.db_engine_version}"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  tags = { Name = "${var.project_name}-db-params" }
}

# ─── RDS MySQL Instance ───────────────────────────────────────

resource "aws_db_instance" "nt-rds" {
  identifier = "${var.project_name}-rds"

  # Engine
  engine         = var.db_engine        # "mysql"
  engine_version = var.db_engine_version # "8.0"
  instance_class = var.db_instance_class # "db.t3.micro"

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 3
  storage_type          = "gp3"
  storage_encrypted     = true

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  # Networking — private, no public access
  db_subnet_group_name   = aws_db_subnet_group.nt-db-subnet-group.name
  vpc_security_group_ids = [var.database_sg_id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  # Maintenance
  parameter_group_name       = aws_db_parameter_group.nt-db-params.name
  backup_retention_period    = 7
  backup_window              = "03:00-04:00"
  maintenance_window         = "mon:04:00-mon:05:00"
  auto_minor_version_upgrade = true

  # Safety
  deletion_protection       = false     # Set true for production
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-rds-final-snapshot"

  tags = { Name = "${var.project_name}-rds" }
}
