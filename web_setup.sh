#!/bin/bash

touch setup_web.sh
# Demande des informations à l'utilisateur
cat <<EOL > setup_web.sh
#!/bin/bash

echo "Starting user_data script for Web Server"

# Demande à l'utilisateur d'entrer les valeurs pour les variables
read -p "Entrez l'IP du bastion : " bastion_private_ip
read -p "Entrez le numéro du serveur : " server_number

# Configuration du proxy
echo "Configuring proxy settings"
echo "Acquire::http::Proxy \"http://\$bastion_private_ip:3128\";" > /etc/apt/apt.conf.d/00proxy
echo "Acquire::https::Proxy \"http://\$bastion_private_ip:3128\";" >> /etc/apt/apt.conf.d/00proxy

# Configuration de l'environnement pour utiliser le proxy
echo "export http_proxy=http://\$bastion_private_ip:3128" >> /etc/environment
echo "export https_proxy=http://\$bastion_private_ip:3128" >> /etc/environment
source /etc/environment

# Met à jour le système et installe Apache
apt update -y
apt upgrade -y
apt install apache2 -y
systemctl start apache2
systemctl enable apache2
echo "<h1>This is Web Server \$server_number</h1>" > /var/www/html/index.html

echo "User_data script for Web Server completed"
EOL

# Donne les permissions d'exécution
chmod +x setup_web.sh
