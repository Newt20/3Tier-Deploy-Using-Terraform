# ─── Tier 1: Public SG (Frontend + Bastion) ──────────────────
# HTTP/HTTPS open to world; SSH from your IP only

resource "aws_security_group" "nt-public-sg" {
  name        = "${var.project_name}-public-sg"
  description = "Tier 1: HTTP/HTTPS public + SSH from trusted IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from your IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-public-sg" }
}

# ─── Tier 2: Private App SG (Backend API EC2) ─────────────────
# Port 8080 only from public tier; SSH only from public SG

resource "aws_security_group" "nt-private-sg" {
  name        = "${var.project_name}-private-sg"
  description = "Tier 2: API port from public tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "API :8080 from frontend/nginx only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nt-public-sg.id]
  }

  ingress {
    description     = "SSH from bastion (public SG) only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.nt-public-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-private-sg" }
}

# ─── Tier 3: Database SG (RDS MySQL) ─────────────────────────
# MySQL port ONLY from backend private SG — nothing else

resource "aws_security_group" "nt-database-sg" {
  name        = "${var.project_name}-database-sg"
  description = "Tier 3: MySQL only from backend SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from backend EC2 only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.nt-private-sg.id]
  }

  # Allow admin access from bastion for queries/migrations
  ingress {
    description     = "MySQL from bastion for admin"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.nt-public-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-database-sg" }
}
