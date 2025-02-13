#!/bin/bash

: '

By default, ports 80 and 443 are used by Nginx but we want to use it for caddy.
Modifies port 80 and 443 to port 81 and 444 respectively.

Called from main.sh

'

echo "freeing the ports..."

sed -i -e 's/80/81/' -e 's/443/444/' /usr/syno/share/nginx/server.mustache /usr/syno/share/nginx/DSM.mustache /usr/syno/share/nginx/WWWService.mustache

synosystemctl restart nginx

echo "script done"
