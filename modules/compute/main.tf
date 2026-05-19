# ─── IAM Role for SSM + CloudWatch ───────────────────────────

resource "aws_iam_role" "nt-ec2-role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nt-ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw" {
  role       = aws_iam_role.nt-ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "nt-ec2-profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.nt-ec2-role.name
}

# ─── Bastion Host ─────────────────────────────────────────────
# Minimal — only used for SSH jump and admin DB access

resource "aws_instance" "nt-bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.public_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.nt-ec2-profile.name
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
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-bastion"
    Role = "bastion"
  }
}

# ─── Frontend EC2 (Tier 1) ────────────────────────────────────
# Nginx serves the static HTML + proxies /api → backend:8080

resource "aws_instance" "nt-frontend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.public_subnet_ids[1]
  vpc_security_group_ids      = [var.public_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.nt-ec2-profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/../../scripts/frontend_userdata.sh", {
    backend_private_ip = var.backend_private_ip
    project_name       = var.project_name
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    tags = { Name = "${var.project_name}-frontend-vol" }
  }
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-frontend-ec2"
    Role = "frontend"
  }
}

# ─── Backend EC2 (Tier 2) ─────────────────────────────────────
# Node.js API running on :8080 — connects to RDS MySQL

resource "aws_instance" "nt-backend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.private_subnet_ids[0]
  vpc_security_group_ids      = [var.private_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.nt-ec2-profile.name
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/../../scripts/backend_userdata.sh", {
    db_endpoint  = var.db_endpoint
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

  tags = {
    Name = "${var.project_name}-backend-ec2"
    Role = "backend"
  }
}
