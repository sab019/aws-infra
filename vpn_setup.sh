#!/bin/bash
exec > /var/log/user-data.log 2>&1
apt update -y
apt upgrade -y 

apt install -y curl

curl -O https://raw.githubusercontent.com/Angristan/openvpn-install/master/openvpn-install.sh

chmod +x openvpn-install.sh
