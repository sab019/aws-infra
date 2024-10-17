#!/bin/bash
exec > /var/log/user-data.log 2>&1
echo "Starting user_data script"

echo "Updating system"
apt update -y
apt upgrade -y

echo "Installing necessary packages"
apt install -y squid haproxy suricata

echo "Configuring Squid"
cat <<EOT > /etc/squid/squid.conf
http_port 3128

acl localnet src 10.74.0.0/16
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager

http_access allow localnet
http_access allow localhost
http_access deny all

coredump_dir /var/spool/squid

refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOT

echo "config ssl"
openssl req -x509 -newkey rsa:2048 -keyout haproxy.key -out haproxy.crt -days 365 -nodes \
-subj "/CN=localhost"

cat haproxy.crt haproxy.key > /etc/ssl/haproxy.pem

chmod 640 /etc/ssl/haproxy.pem

echo "Configuring HAProxy"
cat <<EOT > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend https_frontend
    bind *:443 ssl crt /etc/ssl/haproxy.pem
    mode http
    default_backend http_back

backend http_back
    balance roundrobin
    server web1 ${web1_ip}:80 check
    server web2 ${web2_ip}:80 check
EOT

echo "start services"
systemctl start squid
systemctl enable squid
systemctl start haproxy
systemctl enable haproxy
systemctl start suricata
systemctl enable suricata

echo "Configuring SSH"
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
systemctl restart ssh
systemctl restart squid
echo "User_data script completed"
