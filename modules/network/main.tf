# ─── VPC (from your original aws_vpc.nt-vpc) ─────────────────

resource "aws_vpc" "nt-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true   # Required — RDS endpoint is a DNS name

  tags = { Name = "${var.project_name}-vpc" }
}

# ─── Internet Gateway ─────────────────────────────────────────

resource "aws_internet_gateway" "nt-igw" {
  vpc_id = aws_vpc.nt-vpc.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ─── Public Subnets (Tier 1 — Frontend + Bastion) ─────────────

resource "aws_subnet" "nt-public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.nt-vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  }
}

# ─── Private App Subnets (Tier 2 — Backend API) ───────────────

resource "aws_subnet" "nt-private-app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.nt-vpc.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-app-${count.index + 1}"
    Tier = "private-app"
  }
}

# ─── DB Subnets (Tier 3 — RDS, no internet route) ────────────
# NOTE: This is what was MISSING from your original.
# RDS demands a subnet group with subnets in 2 different AZs.

resource "aws_subnet" "nt-private-db" {
  count = length(var.db_subnet_cidrs)

  vpc_id            = aws_vpc.nt-vpc.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-db-${count.index + 1}"
    Tier = "database"
  }
}

# ─── Elastic IP + NAT Gateway ────────────────────────────────

resource "aws_eip" "nt-nat-eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.nt-igw]
  tags       = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "nt-nat" {
  allocation_id = aws_eip.nt-nat-eip.id
  subnet_id     = aws_subnet.nt-public[0].id
  depends_on    = [aws_internet_gateway.nt-igw]
  tags          = { Name = "${var.project_name}-nat-gw" }
}

# ─── Public Route Table ───────────────────────────────────────

resource "aws_route_table" "nt-public-rt" {
  vpc_id = aws_vpc.nt-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nt-igw.id
  }
  tags = { Name = "${var.project_name}-rt-public" }
}

resource "aws_route_table_association" "nt-public-rt-assoc" {
  count          = length(aws_subnet.nt-public)
  subnet_id      = aws_subnet.nt-public[count.index].id
  route_table_id = aws_route_table.nt-public-rt.id
}

# ─── Private App Route Table (via NAT) ───────────────────────

resource "aws_route_table" "nt-private-app-rt" {
  vpc_id = aws_vpc.nt-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nt-nat.id
  }
  tags = { Name = "${var.project_name}-rt-private-app" }
}

resource "aws_route_table_association" "nt-private-app-rt-assoc" {
  count          = length(aws_subnet.nt-private-app)
  subnet_id      = aws_subnet.nt-private-app[count.index].id
  route_table_id = aws_route_table.nt-private-app-rt.id
}

# ─── DB Route Table (fully isolated — no internet at all) ────

resource "aws_route_table" "nt-private-db-rt" {
  vpc_id = aws_vpc.nt-vpc.id
  # Intentionally no routes — RDS needs no internet access
  tags = { Name = "${var.project_name}-rt-private-db" }
}

resource "aws_route_table_association" "nt-private-db-rt-assoc" {
  count          = length(aws_subnet.nt-private-db)
  subnet_id      = aws_subnet.nt-private-db[count.index].id
  route_table_id = aws_route_table.nt-private-db-rt.id
}
