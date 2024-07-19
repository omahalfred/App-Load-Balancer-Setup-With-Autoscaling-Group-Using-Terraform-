# Create vpc
resource "aws_vpc" "main_vpc" {
  cidr_block          = "10.0.0.0/16"
  enable_dns_support  = true
  enable_dns_hostnames = true
  instance_tenancy    = "default"

  tags = {
    Name = "main vpc"
  }
}

# Create subnet
variable "vpc_availability_zones" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b"]  
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, count.index+1)
  count      = length(var.vpc_availability_zones)
  availability_zone = element(var.vpc_availability_zones, count.index)
  tags = {
    Name = "public subnet ${count.index+1}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, count.index+3)
  count      = length(var.vpc_availability_zones)
  availability_zone = element(var.vpc_availability_zones, count.index)
  tags = {
    Name = "private subnet ${count.index+1}"
  }
}

#Create IGW
resource "aws_internet_gateway" "igw_vpc" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "Internet gateway"
  }
}

#RT for public subnet
resource "aws_route_table" "route_table_public_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_vpc.id
  }
  tags = {
    Name = "public subnet route table"
  }    
}

# association between RT and IG
resource "aws_route_table_association" "public_subnet_association" {
  route_table_id = aws_route_table.route_table_public_subnet.id
  count = length(var.vpc_availability_zones)
  subnet_id = element(aws_subnet.public_subnet[*].id, count.index)
}

#EIP
resource "aws_eip" "eip" {
  domain   = "vpc"
  depends_on = [aws_internet_gateway.igw_vpc]
}

#Nat gateway
resource "aws_nat_gateway" "nat-gateway" {
  subnet_id = element(aws_subnet.private_subnet[*].id, 0)
  allocation_id = aws_eip.eip.id
  depends_on = [aws_internet_gateway.igw_vpc]
  tags = {
    Name = "Nat Gateway"
  }
}

#RT for private subnet
resource "aws_route_table" "route_table_private_subnet" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gateway.id
  }
  tags = {
    Name = "private subnet route table"
  }    
}

# association between RT and NatGateway
resource "aws_route_table_association" "private_subnet_association" {
  route_table_id = aws_route_table.route_table_private_subnet.id
  count = length(var.vpc_availability_zones)
  subnet_id = element(aws_subnet.private_subnet[*].id, count.index)
}