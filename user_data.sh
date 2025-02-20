#!/bin/bash
echo "Hello, World" > /var/www/html/index.html
nohup busybox httpd -f -p ${var.server_port} &
