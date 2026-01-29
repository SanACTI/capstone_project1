#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd


cat <<EOF > /var/www/html/index.html
<html>
<head>
<title>Terraform Web Server</title>
</head>
<body>
<h1> Web Server Deployed using Terraform -Sanskriti</h1>
<p>EC2 + Apache running successfully</p>
</body>
</html>
EOF
