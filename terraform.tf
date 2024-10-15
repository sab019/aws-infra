provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# VPC principal
resource "aws_vpc" "main" {
  cidr_block = "10.74.0.0/16"

  tags = {
    Name = "Main VPC"
  }
}

# Sous-réseaux
resource "aws_subnet" "bastion" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.74.1.0/24"

  tags = {
    Name = "Bastion Subnet"
  }
}

resource "aws_subnet" "web1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.74.2.0/24"

  tags = {
    Name = "Web1 Subnet"
  }
}

resource "aws_subnet" "web2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.74.3.0/24"

  tags = {
    Name = "Web2 Subnet"
  }
}

# Internet Gateway
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

# Route table pour le sous-réseau web1
resource "aws_route_table" "web1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Web1 Route Table"
  }
}

resource "aws_route_table_association" "web1" {
  subnet_id      = aws_subnet.web1.id
  route_table_id = aws_route_table.web1.id
}

# Peering VPC entre web1 et bastion
resource "aws_vpc_peering_connection" "web1_to_bastion" {
  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = aws_vpc.main.id
  auto_accept   = true

  tags = {
    Name = "Peering between Web1 and Bastion subnets"
  }
}

# Routes pour le peering
resource "aws_route" "web1_to_bastion" {
  route_table_id            = aws_route_table.web1.id
  destination_cidr_block    = aws_subnet.bastion.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.web1_to_bastion.id
}

resource "aws_route" "bastion_to_web1" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = aws_subnet.web1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.web1_to_bastion.id
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
    from_port   = 3128
    to_port     = 3128
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Squid proxy access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for HAProxy"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for HAProxy"
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

# Instance EC2 pour le bastion
resource "aws_instance" "bastion" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.bastion.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name      = "ssh-key"

  user_data = templatefile("bastion_setup.sh", {
    web1_ip = aws_instance.web1.private_ip,
    web2_ip = aws_instance.web2.private_ip
  })

  tags = {
    Name = "Bastion Host"
  }

  depends_on = [aws_instance.web1, aws_instance.web2]
}

# Instances EC2 pour les serveurs web
resource "aws_instance" "web1" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.web1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name      = "ssh-key"

  user_data = templatefile("web1_setup.sh", {
    server_number = 1,
    bastion_private_ip = aws_subnet.bastion.cidr_block
  })

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

  user_data = templatefile("web2_setup.sh", {
    server_number = 2,
    bastion_private_ip = aws_subnet.bastion.cidr_block
  })

  tags = {
    Name = "Web2 Server"
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
