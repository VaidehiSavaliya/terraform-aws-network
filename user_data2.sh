#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "Welcome to the AWS-Terraform automation" > /var/www/html/index.html
