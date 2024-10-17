provider "aws" {
  region  = "us-east-1"
  profile = "default"
  version = "~> 5.0"
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
resource "aws_route_table" "private_main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.private_main.id
}

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

  user_data = templatefile("web_setup.sh", {})

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

  user_data = templatefile("web_setup.sh", {})

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
  from_port   = 3128
  to_port     = 3128
  protocol    = "tcp"
  cidr_blocks = ["10.74.2.0/24"]  # Autoriser les machines web à accéder au proxy
  description = "HTTP Proxy access from web servers"
  }

  ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # Autoriser les machines web à accéder au proxy
  description = "HTTP Proxy access from web servers"
  }

  ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # Autoriser les machines web à accéder au proxy
  description = "HTTP Proxy access from web servers"
  }


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

# Internet Gateway pour le VPC intranet (où se trouve le VPN)
resource "aws_internet_gateway" "intranet_igw" {
  vpc_id = aws_vpc.intranet_vpc.id

  tags = {
    Name = "Intranet IGW"
  }
}

# Route table pour le sous-réseau VPN public
resource "aws_route_table" "vpn_public" {
  vpc_id = aws_vpc.intranet_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.intranet_igw.id
  }

  tags = {
    Name = "VPN Public Route Table"
  }
}

# Associer la route au sous-réseau VPN public
resource "aws_route_table_association" "vpn_public_assoc" {
  subnet_id      = aws_subnet.vpn_public.id
  route_table_id = aws_route_table.vpn_public.id
}

# Instance EC2 pour le serveur VPN
resource "aws_instance" "vpn" {
  ami                         = "ami-0747bdcabd34c712a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.vpn_public.id
  vpc_security_group_ids      = [aws_security_group.vpn.id]
  associate_public_ip_address  = true
  key_name                    = "ssh-key"

  user_data = templatefile("vpn_setup.sh", {})

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

  # Ajouter cette section pour autoriser SSH (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Remplacez par une plage d'adresses IP plus restrictive si nécessaire
    description = "SSH access"
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

# Instance EC2 pour la base de données dans le sous-réseau privé du VPC Intranet
resource "aws_instance" "db" {
  ami                         = "ami-0747bdcabd34c712a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.db_private.id  # Sous-réseau privé pour la base de données
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = "ssh-key"

  user_data = templatefile("mysql_setup.sh", {
    db_backup_private_ip = aws_instance.db_backup.private_ip
  })

  tags = {
    Name = "DB Server"
  }
}

# Instance EC2 pour le serveur de backup bdd
resource "aws_instance" "db_backup" {
  ami                         = "ami-0747bdcabd34c712a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.db_private.id  # Sous-réseau privé pour la base de données
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = "ssh-key"

  tags = {
    Name = "DB-backup Server"
  }
}

# Groupe de sécurité pour le serveur de base de données
resource "aws_security_group" "db_backup" {
  name        = "db_backup_sg"
  description = "Security group for backup bdd server"
  vpc_id      = aws_vpc.intranet_vpc.id


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.76.0.0/16"]  # SSH access from within the VPC
    description = "SSH access from within the VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DB_BACKUP SG"
  }
}


# Groupe de sécurité pour le serveur de base de données
resource "aws_security_group" "db" {
  name        = "db_sg"
  description = "Security group for database server"
  vpc_id      = aws_vpc.intranet_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.76.0.0/16"]  # Restrict to the Intranet VPC IP range
    description = "MySQL access from within the Intranet VPC"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.76.0.0/16"]  # SSH access from within the VPC
    description = "SSH access from within the VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DB SG"
  }
}

# Elastic IP pour la passerelle NAT
resource "aws_eip" "nat" {
  vpc = true
}

# Création de la passerelle NAT
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.vpn_public.id  # Doit être dans le sous-réseau public

  tags = {
    Name = "Main NAT Gateway"
  }
}

# Route table pour les sous-réseaux privés
resource "aws_route_table" "private_intranet" {
  vpc_id = aws_vpc.intranet_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id  # Route vers la passerelle NAT
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Association de la route au sous-réseau privé
resource "aws_route_table_association" "db_private" {
  subnet_id      = aws_subnet.db_private.id
  route_table_id = aws_route_table.private_intranet.id
}

