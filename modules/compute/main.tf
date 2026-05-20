# ─── Bastion Host ─────────────────────────────────────────────
resource "aws_instance" "nt-bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.public_sg_id]
  # iam_instance_profile        = aws_iam_instance_profile.nt-ec2-profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y mysql-client curl
    hostnamectl set-hostname ${var.project_name}-bastion
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
    encrypted             = true
    tags = { Name = "${var.project_name}-bastion-vol" }
  }
  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-bastion", Role = "bastion" }
}

# ─── Frontend EC2 (Tier 1) ────────────────────────────────────
resource "aws_instance" "nt-frontend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.public_subnet_ids[1]
  vpc_security_group_ids      = [var.public_sg_id]
  # iam_instance_profile        = aws_iam_instance_profile.nt-ec2-profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/../../scripts/frontend_userdata.sh", {
    backend_private_ip = aws_instance.nt-backend.private_ip # Link to local backend resource
    project_name       = var.project_name
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    tags = { Name = "${var.project_name}-frontend-vol" }
  }
  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-frontend-ec2", Role = "frontend" }
}

# ─── Database EC2 Instance (Tier 3) ───────────────────────────
# Placed BEFORE backend so the IP is available for the backend config

resource "aws_instance" "nt-db-server" {
  ami                    = var.ami_id
  instance_type          = var.db_instance_class
  # key_name               = var.key_name # 
  subnet_id              = var.db_subnet_ids[0] 
  vpc_security_group_ids = [var.database_sg_id] 
  
  # iam_instance_profile   = aws_iam_instance_profile.nt-ec2-profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.allocated_storage
    delete_on_termination = true
    encrypted             = true
    tags                  = { Name = "${var.project_name}-db-vol" }
  }

  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y mysql-server
              
              # Configure MySQL to listen on all IPs
              sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
              systemctl restart mysql

              # Create DB and User
              mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${var.db_name}\`;"
              mysql -u root -e "CREATE USER IF NOT EXISTS '${var.db_username}'@'%' IDENTIFIED BY '${var.db_password}';"
              mysql -u root -e "GRANT ALL PRIVILEGES ON \`${var.db_name}\`.* TO '${var.db_username}'@'%';"
              mysql -u root -e "FLUSH PRIVILEGES;"
              EOF

  tags = { Name = "${var.project_name}-db-server", Role = "database" }
}

# ─── Backend EC2 (Tier 2) ─────────────────────────────────────
# Node.js API running on :8080 — connects to DB EC2

resource "aws_instance" "nt-backend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.private_subnet_ids[0]
  vpc_security_group_ids      = [var.private_sg_id]
  # iam_instance_profile        = aws_iam_instance_profile.nt-ec2-profile.name
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/../../scripts/backend_userdata.sh", {
    db_endpoint  = aws_instance.nt-db-server.private_ip
    db_name      = var.db_name
    db_username  = var.db_username
    db_password  = var.db_password
    db_port      = var.db_port
    project_name = var.project_name
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    tags = { Name = "${var.project_name}-backend-vol" }
  }

  tags = { Name = "${var.project_name}-backend-ec2", Role = "backend" }
  
  # Ensure DB is created before backend tries to configure env
  depends_on = [aws_instance.nt-db-server]
}