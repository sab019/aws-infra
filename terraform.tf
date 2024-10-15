provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# VPC principal
resource "aws_vpc" "main" {
  cidr_block = "10.74.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Main VPC"
  }
}

# Sous-réseaux du VPC principal
resource "aws_subnet" "bastion" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.74.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Bastion Subnet"
  }
}

resource "aws_subnet" "web1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.74.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Web1 Subnet"
  }
}

resource "aws_subnet" "web2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.74.3.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "Web2 Subnet"
  }
}

# Internet Gateway pour le VPC principal
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main IGW"
  }
}

# Route table pour le sous-réseau public (bastion)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.bastion.id
  route_table_id = aws_route_table.public.id
}

# Route table pour les sous-réseaux privés
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "web1" {
  subnet_id      = aws_subnet.web1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "web2" {
  subnet_id      = aws_subnet.web2.id
  route_table_id = aws_route_table.private.id
}

# Nouveau VPC pour la machine ICMP
resource "aws_vpc" "icmp_vpc" {
  cidr_block = "10.75.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ICMP VPC"
  }
}

# Sous-réseau pour la machine ICMP
resource "aws_subnet" "icmp" {
  vpc_id     = aws_vpc.icmp_vpc.id
  cidr_block = "10.75.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ICMP Subnet"
  }
}

# Peering VPC entre le VPC principal et le VPC ICMP
resource "aws_vpc_peering_connection" "main_to_icmp" {
  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = aws_vpc.icmp_vpc.id
  auto_accept   = true

  tags = {
    Name = "Peering between Main and ICMP VPCs"
  }
}

# Routes pour le peering
resource "aws_route" "main_to_icmp" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = aws_vpc.icmp_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_icmp.id
}

resource "aws_route" "icmp_to_main" {
  route_table_id            = aws_route_table.icmp.id
  destination_cidr_block    = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_icmp.id
}

# Route table pour le VPC ICMP
resource "aws_route_table" "icmp" {
  vpc_id = aws_vpc.icmp_vpc.id

  tags = {
    Name = "ICMP Route Table"
  }
}

resource "aws_route_table_association" "icmp" {
  subnet_id      = aws_subnet.icmp.id
  route_table_id = aws_route_table.icmp.id
}

# Groupe de sécurité pour le bastion
resource "aws_security_group" "bastion" {
  name        = "bastion_sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.icmp_vpc.cidr_block]
    description = "ICMP from ICMP VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion SG"
  }
}

# Groupe de sécurité pour les serveurs web
resource "aws_security_group" "web" {
  name        = "web_sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description = "HTTP from bastion"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description = "SSH from bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web SG"
  }
}

# Groupe de sécurité pour la machine ICMP
resource "aws_security_group" "icmp" {
  name        = "icmp_sg"
  description = "Security group for ICMP machine"
  vpc_id      = aws_vpc.icmp_vpc.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "ICMP from Main VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ICMP SG"
  }
}

# Instance EC2 pour le bastion
resource "aws_instance" "bastion" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.bastion.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name      = "ssh-key"

  tags = {
    Name = "Bastion Host"
  }
}

# Instances EC2 pour les serveurs web
resource "aws_instance" "web1" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.web1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name      = "ssh-key"

  tags = {
    Name = "Web1 Server"
  }
}

resource "aws_instance" "web2" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.web2.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name      = "ssh-key"

  tags = {
    Name = "Web2 Server"
  }
}

# Instance EC2 pour la machine ICMP
resource "aws_instance" "icmp" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.icmp.id
  vpc_security_group_ids = [aws_security_group.icmp.id]
  key_name      = "ssh-key"

  tags = {
    Name = "ICMP Machine"
  }
}

# Outputs
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
  description = "The public IP address of the bastion host"
}

output "web1_private_ip" {
  value = aws_instance.web1.private_ip
  description = "The private IP address of Web Server 1"
}

output "web2_private_ip" {
  value = aws_instance.web2.private_ip
  description = "The private IP address of Web Server 2"
}

output "icmp_private_ip" {
  value = aws_instance.icmp.private_ip
  description = "The private IP address of the ICMP machine"
}
