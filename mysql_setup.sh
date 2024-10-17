#!/bin/bash

# Variables
db_backup_private_ip="${db_backup_private_ip}"
mysql_user="root"  # Changez cela si nécessaire
mysql_password="root"  # Mettez ici le mot de passe MySQL
mysql_database="mysql"  # Nom de la base de données à dumper

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

# Sécurisation de l'installation MySQL via des commandes SQL
echo "Securing MySQL installation..."
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$mysql_password';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

echo "MySQL installation and configuration completed successfully."

# Afficher l'état du service MySQL
systemctl status mysql

# Ajout des tâches cron
echo "Configuring cron jobs for MySQL dump and backup transfer..."

# Combiner les deux commandes crontab en une seule pour éviter les suppressions mutuelles
(crontab -l 2>/dev/null; echo "0 22 * * * mysqldump -u $mysql_user -p$mysql_password $mysql_database > /home/ubuntu/dump.sql"; echo "0 23 * * * scp -i /etc/ssl/ssh-key /home/ubuntu/dump.sql ubuntu@$db_backup_private_ip:/home/ubuntu/") | crontab -

echo "Cron jobs added successfully."

