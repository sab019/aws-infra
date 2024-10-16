provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# VPC principal
resource "aws_vpc" "main" {
  cidr_block           = "10.74.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Main VPC"
  }
}

# Sous-réseau du bastion
resource "aws_subnet" "bastion" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.74.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Bastion Subnet"
  }
}

# Sous-réseau pour les serveurs web (web1 et web2)
resource "aws_subnet" "web" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.74.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Web Subnet"
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

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.private.id
}

# Cluster RDS pour la base de données
#resource "aws_rds_cluster" "intranet_db_backup" {
#  cluster_identifier       = "intranet-db-backup"
#  engine                   = "aurora-postgresql"
#  engine_version	   = "12.19"
#  master_username          = "dbadmin"
#  master_password          = "DBPassword123!"
#  backup_retention_period   = 7
#  preferred_backup_window   = "02:00-03:00"
#  skip_final_snapshot       = true
#
#  tags = {
#    Name = "Intranet DB Backup"
#  }
#}

# Instance RDS pour le cluster
#resource "aws_rds_cluster_instance" "intranet_db_backup_instance" {
#  cluster_identifier = aws_rds_cluster.intranet_db_backup.id
#  instance_class     = "db.r4.large"
#  engine             = "aurora-postgresql"
#  engine_version     = "12.19"  # Spécifiez la version appropriée
#  
#  tags = {
#    Name = "Intranet DB Backup Instance"
#  }
#}

# VPC pour l'Intranet avec sous-réseaux
resource "aws_vpc" "intranet_vpc" {
  cidr_block           = "10.76.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Intranet VPC"
  }
}

# Sous-réseau pour le serveur VPN (public)
resource "aws_subnet" "vpn_public" {
  vpc_id            = aws_vpc.intranet_vpc.id
  cidr_block        = "10.76.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "VPN Public Subnet"
  }
}

# Sous-réseau pour les bases de données (privé)
resource "aws_subnet" "db_private" {
  vpc_id            = aws_vpc.intranet_vpc.id
  cidr_block        = "10.76.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "DB Private Subnet"
  }
}

# Instance EC2 pour le bastion
resource "aws_instance" "bastion" {
  ami                         = "ami-0747bdcabd34c712a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.bastion.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address  = true
  key_name                    = "ssh-key"

  user_data = templatefile("bastion_setup.sh", {
    web1_ip = aws_instance.web1.private_ip,
    web2_ip = aws_instance.web2.private_ip  # Both web servers in the same subnet
  })

  tags = {
    Name = "Bastion Host"
  }
}

# Instances EC2 pour les serveurs web
resource "aws_instance" "web1" {
  ami                         = "ami-0747bdcabd34c712a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.web.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = "ssh-key"

 # user_data = templatefile("web_setup.sh", {
 #   server_number       = 1,
 #   bastion_private_ip  = aws_instance.bastion.private_ip
 # })	

  tags = {
    Name = "Web Server 1"
  }
}

resource "aws_instance" "web2" {
  ami                         = "ami-0747bdcabd34c712a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.web.id  # Moved to the same subnet as web1
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = "ssh-key"

 # user_data = templatefile("web_setup.sh", {
 #   server_number       = 2,
 #   bastion_private_ip  = aws_instance.bastion.private_ip
 # })

  tags = {
    Name = "Web Server 2"
  }
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
    from_port      = 80
    to_port        = 80
    protocol       = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description    = "HTTP from bastion"
  }

  ingress {
    from_port      = 22
    to_port        = 22
    protocol       = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description    = "SSH from bastion"
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

# Instance EC2 pour le serveur VPN
resource "aws_instance" "vpn" {
  ami                         = "ami-0747bdcabd34c712a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.vpn_public.id
  vpc_security_group_ids      = [aws_security_group.vpn.id]
  associate_public_ip_address  = true
  key_name                    = "ssh-key"

  tags = {
    Name = "VPN Server"
  }
}

# Groupe de sécurité pour le serveur VPN
resource "aws_security_group" "vpn" {
  name        = "vpn_sg"
  description = "Security group for VPN server"
  vpc_id      = aws_vpc.intranet_vpc.id

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"  # Port pour OpenVPN
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenVPN access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "VPN SG"
  }
}

