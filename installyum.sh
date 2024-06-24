#!/bin/bash

# Check if firewalld is installed
if ! command -v firewall-cmd &> /dev/null
then
    # Install firewalld
    sudo yum install firewalld -y
fi

# Enable and start firewalld
sudo systemctl enable firewalld && sudo systemctl start firewalld

# Allow specific ports for incoming traffic
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=22/udp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=443/udp
sudo firewall-cmd --permanent --add-port=2060/tcp
sudo firewall-cmd --permanent --add-port=2060/udp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=80/udp

sudo iptables -A INPUT -s 185.188.106.10 -j DROP #www.Digikala.com
sudo iptables -A OUTPUT -d 185.188.106.10 -j DROP #www.Digikala.com
sudo iptables -A INPUT -d 86.104.35.19 -j DROP #www.Snapp.ir
sudo iptables -A OUTPUT -d 86.104.35.19 -j DROP #www.Snapp.ir
sudo iptables -A INPUT -d 185.143.234.225 -j DROP #www.snappfood.ir
sudo iptables -A OUTPUT -d 185.143.234.225 -j DROP #www.snappfood.ir
sudo iptables -A INPUT -d 185.143.233.81 -j DROP #www.tapsi.ir
sudo iptables -A OUTPUT -d 185.143.233.81 -j DROP #www.tapsi.ir
sudo iptables -A INPUT -d 185.143.233.81 -j DROP #www.app.tapsi.ir
sudo iptables -A OUTPUT -d 185.143.233.81 -j DROP #www.app.tapsi.ir 

# Reload the firewall to apply changes
sudo firewall-cmd --reload

# Update package lists
sudo yum update -y

# Upgrade packages to the latest version
sudo yum upgrade -y

# Install the latest versions of all packages installed on the system
sudo yum distro-sync -y

# Upgrade to the latest version of the distribution
sudo yum update -y

# Install Certbot For SSL
sudo yum install certbot python3-certbot-nginx -y
sudo yum install nginx -y

sudo systemctl stop nginx

read -p "Enter Your Domain Name (e.g., my-domain.com): " DOMAIN

# Check if Certbot is installed and install if necessary
if ! command -v certbot &> /dev/null
then
    sudo yum install certbot -y
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