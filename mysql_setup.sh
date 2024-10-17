#!/bin/bash

# Rediriger les sorties vers un fichier log
exec > /var/log/mysql-install.log 2>&1

echo "Starting MySQL installation script"

# Mise à jour du système
echo "Updating system packages..."
apt update -y && apt upgrade -y

# Installation de MySQL Server
echo "Installing MySQL Server..."
apt install -y mysql-server

# Démarrage et activation de MySQL
echo "Starting MySQL service..."
systemctl start mysql
systemctl enable mysql

# Sécurisation de l'installation MySQL
echo "Securing MySQL installation..."
mysql_secure_installation <<EOF

Y
root
root
Y
Y
Y
Y
EOF

echo "MySQL installation and configuration completed successfully."

# Afficher l'état du service MySQL
systemctl status mysql

