#!/bin/bash
exec > /var/log/user-data.log 2>&1
echo "Starting user_data script for Web Server"

# Configuration du proxy
echo "Configuring proxy settings"
echo "Acquire::http::Proxy \"http://${bastion_private_ip}:3128\";" > /etc/apt/apt.conf.d/00proxy
echo "Acquire::https::Proxy \"http://${bastion_private_ip}:3128\";" >> /etc/apt/apt.conf.d/00proxy

# Configuration de l'environnement pour utiliser le proxy
echo "export http_proxy=http://${bastion_private_ip}:3128" >> /etc/environment
echo "export https_proxy=http://${bastion_private_ip}:3128" >> /etc/environment
source /etc/environment

apt update -y
apt upgrade -y
apt install apache2 -y
systemctl start apache2
systemctl enable apache2
echo "<h1>This is Web Server ${server_number}</h1>" > /var/www/html/index.html

echo "User_data script for Web Server completed"

