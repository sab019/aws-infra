#!/bin/bash

# Installer OpenVPN et Easy-RSA
apt-get update
apt-get install -y openvpn easy-rsa

# Créer un répertoire pour les certificats
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

# Initialiser le PKI
./easyrsa init-pki

# Générer le certificat d'autorité (CA)
echo "yes" | ./easyrsa build-ca nopass

# Générer le certificat et la clé pour le serveur
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Générer Diffie-Hellman
./easyrsa gen-dh

# Créer le fichier de configuration du serveur OpenVPN
cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

# Activer le routage IP
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE

# Démarrer le service OpenVPN
systemctl start openvpn@server
systemctl enable openvpn@server

# Afficher les informations de connexion
echo "VPN Server est configuré. Utilisez les fichiers suivants pour vous connecter :"
echo "CA Certificate: /etc/openvpn/easy-rsa/pki/ca.crt"
echo "Server Certificate: /etc/openvpn/easy-rsa/pki/issued/server.crt"
echo "Server Key: /etc/openvpn/easy-rsa/pki/private/server.key"
echo "DH Parameters: /etc/openvpn/easy-rsa/pki/dh.pem"

