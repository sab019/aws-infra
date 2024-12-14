
# Étape 1 : Transfert et configuration initiale

## 1.1) Transfert de la clé RSA vers le bastion

Transférer la clé RSA vers le bastion :

`scp -i ../ssh-key.pem ../ssh-key.pem ubuntu@ip-pub-bastion:~`

Se connecter au bastion :

`ssh -i ../ssh-key.pem ubuntu@ip-pub-bastion`

## 1.2) Connexion sur les serveurs web
Se connecter à chaque serveur web (répétez cette 
procédure sur les deux serveurs) :

`ssh -i ssh-key.pem ubuntu@ip-pv-webserver`

Passer en mode superutilisateur :
`sudo su`

Accéder à la racine du serveur :
`cd /`

Exécuter le script de configuration :
`./setup_web.sh`

Lors de l'exécution du script, entrer l'IP privée du bastion et le numéro du serveur web lorsque demandé.

## 1.3) Redémarrer les services HAProxy et Squid sur le bastion

Sur le bastion, redémarrer les services Squid et HAProxy :

`systemctl restart squid haproxy`

# Étape 2 : Configuration du VPN

Se connecter au serveur VPN :

`ssh -i ssh-key.pem ubuntu@ip-pub-vpn`

Passer en mode superutilisateur :
`sudo su`

Accéder à la racine du serveur :
`cd /`

Exécuter le script d'installation OpenVPN :
`./openvpn-install.sh`

Après l'installation, copier le fichier .ovpn dans le répertoire /home/ubuntu pour l'accès au VPN.

# Étape 3 : Ajouter la clé RSA SSH sur la base de données

Copier la clé RSA dans le répertoire /etc/ssl/ sur le serveur de la base de données.

Modifier les permissions de la clé pour la sécuriser :

`chmod 600 /etc/ssl/ssh-key`
