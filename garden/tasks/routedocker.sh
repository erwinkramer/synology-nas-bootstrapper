: '

This script is used to directly route traffic from the Synology NAS to the Docker containers so it preserves the sources IPs.
Please see https://gist.github.com/pedrolamas/db809a2b9112166da4a2dbf8e3a72ae9?permalink_comment_id=4074559#gistcomment-4074559

Control Panel > Task Scheduler > Create > Triggered Task > User-defined script. 

Set User to 'root' and leave the Event as 'Boot-up',
go to Task Settings and paste the following in User-defined script:

bash /volume1/docker/projects/garden/tasks/routedocker.sh

'

ports_tcp=(80 443 6432 50777 53)
ports_udp=(53)
currentAttempt=0
totalAttempts=10
delay=15

echo "setting the ip tables..."

while [ $currentAttempt -lt $totalAttempts ]
do
	currentAttempt=$(( $currentAttempt + 1 ))
	
	echo "Attempt $currentAttempt of $totalAttempts..."
	
	result=$(iptables-save)

	if [[ $result =~ "-A DOCKER -i docker0 -j RETURN" ]]; then
		echo "Docker rules found! Modifying..."
		
		for port in "${ports_tcp[@]}"; do
			echo "setting tcp port '$port' for docker"
			iptables -t nat -A PREROUTING -p tcp --dport $port -m addrtype --dst-type LOCAL -j DOCKER
		done

		for port in "${ports_udp[@]}"; do
			echo "setting udp port '$port' for docker"
			iptables -t nat -A PREROUTING -p udp --dport $port -m addrtype --dst-type LOCAL -j DOCKER
		done

		echo "Done!"
		
		break
	fi
	
	echo "Docker rules not found! Sleeping for $delay seconds..."
	
	sleep $delay
done

echo "script done"
