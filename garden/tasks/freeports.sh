: '

By default, ports 80 and 443 are used by Nginx but we want to use it for caddy.
Modifies port 80 and 443 to port 81 and 444 respectively.

Control Panel > Task Scheduler > Create > Triggered Task > User-defined script. 

Set User to 'root' and leave the Event as 'Boot-up',
go to Task Settings and paste the following in User-defined script:

bash /volume1/docker/projects/garden/tasks/freeports.sh

'

echo "freeing the ports..."

sed -i -e 's/80/81/' -e 's/443/444/' /usr/syno/share/nginx/server.mustache /usr/syno/share/nginx/DSM.mustache /usr/syno/share/nginx/WWWService.mustache

synosystemctl restart nginx

echo "script done"
