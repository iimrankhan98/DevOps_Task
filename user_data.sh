#!/bin/bash
set -eux

# Ensure SSM and updates
yum update -y

# Install Apache (httpd) and PHP
yum install -y httpd php php-mysqlnd

cat >/var/www/html/index.php <<'PHP'
<?php
$instance = file_get_contents("http://169.254.169.254/latest/meta-data/instance-id");
echo "<h1>PHP on Apache via ASG</h1>";
echo "<p>Instance: $instance</p>";
?>
PHP

systemctl enable httpd
systemctl start httpd
