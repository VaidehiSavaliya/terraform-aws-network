#!/bin/bash
apt update -y
apt install -y apache2
systemctl start apache2
systemctl enable apache2

echo "Hello from $(hostname -f) = Instance 1" > /var/www/html/index.html

