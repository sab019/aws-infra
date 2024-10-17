#!/bin/bash

# Variables
db_backup_private_ip="${db_backup_private_ip}"
mysql_user="root"  # Changez cela si nécessaire
mysql_password="root"  # Mettez ici le mot de passe MySQL
mysql_database="test_db"  # Nom de la base de données à dumper

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

mysql -u root <<EOF
-- Création de la base de données
CREATE DATABASE test_db;

-- Sélection de la base de données
USE test_db;

-- Création de la table de test
CREATE TABLE test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,  -- Colonne pour l'ID unique
    name VARCHAR(100) NOT NULL,         -- Colonne pour le nom
    email VARCHAR(100) NOT NULL,        -- Colonne pour l'email
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Colonne pour la date de création
);

-- Insertion de quelques données de test
INSERT INTO test_table (name, email)
VALUES
    ('Alice Dupont', 'alice.dupont@example.com'),
    ('Bob Martin', 'bob.martin@example.com'),
    ('Charlie Legrand', 'charlie.legrand@example.com');
EOF

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


echo "Starting user_data script for Web Server"


# installe Apache
apt install apache2 -y
apt install php7.2 -y
apt install php-mysql -y

systemctl start apache2
systemctl enable apache2

cat <<EOL > /var/www/index.php
<h1>This is Web Server intranet</h1>
<?php
// Configuration de la base de données
$host = 'localhost';
$dbname = 'test_db';  // Nom de la base de données
$username = 'root';   // Nom d'utilisateur MySQL
$password = 'root';       // Mot de passe MySQL

try {
    // Connexion à la base de données avec PDO
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $sql = 'SELECT * FROM test_table;';
    $stmt = $pdo->query($sql);

    // Vérification s'il y a des résultats
        echo '<ul>';
        // Boucle à travers chaque utilisateur et affichage dans une liste HTML
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo '<li>' . htmlspecialchars($row['name']) . '</li>';
        }
        echo '</ul>';

} catch (PDOException $e) {
    // Gestion des erreurs de connexion ou de requête
    echo 'Erreur de connexion : ' . $e->getMessage();
}
?>
EOL

echo "User_data script for Web Server completed"
