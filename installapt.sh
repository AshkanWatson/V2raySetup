#!/bin/bash

# Enabling the firewall
sudo ufw enable

# Allow specific ports for incoming traffic
sudo ufw allow 22
sudo ufw allow 22/tcp
sudo ufw allow 22/udp
sudo ufw allow 443
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw allow 2060
sudo ufw allow 2060/tcp
sudo ufw allow 2060/udp
sudo ufw allow 80
sudo ufw allow 80/tcp
sudo ufw allow 80/udp
# Block a Iranian Site IP address
sudo ufw deny from 185.188.106.10 #www.Digikala.com
sudo ufw deny from 86.104.35.19 #www.Snapp.ir
sudo ufw deny from 185.143.234.225 #www.snappfood.ir
sudo ufw deny from 185.143.233.81 #www.tapsi.ir
sudo ufw deny from 185.143.233.81 #www.app.tapsi.ir
# Allow Outgoing traffic for all
sudo ufw default allow outgoing

# Apply changes
sudo ufw reload

# Update package lists
sudo apt-get update -y

# Upgrade packages to the latest version
sudo apt-get upgrade -y

# Install the latest versions of all packages installed on the system
sudo apt-get dist-upgrade -y

# Upgrade to the latest version of the distribution
sudo apt-get full-upgrade -y

# Removing Old packages
sudo apt-get autoremove -y

# Install Certbot For SSL
sudo apt install certbot python3-certbot-nginx -y

sudo systemctl stop nginx

read -p "Enter Your Domain Name (e.g., my-domain.com): " DOMAIN

# Check if Certbot is installed and install if necessary
if ! command -v certbot &> /dev/null
then
    sudo apt-get install certbot -y
fi

# Generate Let's Encrypt SSL certificate using Certbot
sudo certbot certonly --standalone --preferred-challenges http -d $DOMAIN

# Copy certificate files to /root
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /root
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /root

# Change permissions of copied files
chmod 600 /root/fullchain.pem
chmod 600 /root/privkey.pem

sudo systemctl start nginx