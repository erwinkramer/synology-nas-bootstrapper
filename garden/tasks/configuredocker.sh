#!/bin/bash

: '

This script is used to:
 - directly route traffic from the Synology NAS to the Docker containers so it preserves the sources IPs.
 - set the group permissions for docker socket

Please see https://gist.github.com/pedrolamas/db809a2b9112166da4a2dbf8e3a72ae9?permalink_comment_id=4074559#gistcomment-4074559

Called from main.sh

'

declare -A ports=(
	[tcp]="80 443 6432 50777 1414 53 9443"
	[udp]="53"
)
groupnamedocker=$1

currentAttempt=0
totalAttempts=30
delay=1

echo "setting the ip tables..."

while [ $currentAttempt -lt $totalAttempts ]; do
	currentAttempt=$(($currentAttempt + 1))

	echo "Attempt $currentAttempt of $totalAttempts..."

	if iptables-save | grep -q "\-A DOCKER -i docker0 -j RETURN"; then
		echo "Docker rules found! Modifying..."

		for protocol in "${!ports[@]}"; do
			for port in ${ports[$protocol]}; do
				echo "setting $protocol port '$port' for docker"
				iptables -t nat -A PREROUTING -p $protocol --dport $port -m addrtype --dst-type LOCAL -j DOCKER
				iptables -t nat -A OUTPUT -p $protocol --dport $port -m addrtype --dst-type LOCAL -j DOCKER
			done
		done

		echo "Done!"
		break
	else
		echo "Docker rules not found! Sleeping for $delay second(s)..."
		sleep $delay
	fi
done

echo "setting the docker socket group permissions..."
currentAttempt=0

while [ $currentAttempt -lt $totalAttempts ]; do
	currentAttempt=$(($currentAttempt + 1))

	echo "Attempt $currentAttempt of $totalAttempts..."

	if [ -e /var/run/docker.sock ]; then
		echo "Docker socket found! Modifying..."

		currentdockersockgroupowner=$(ls -ld /var/run/docker.sock | awk '{print $4}')
		echo "giving group ownership of 'docker.sock' from $currentdockersockgroupowner to $groupnamedocker..."
		chown root:$groupnamedocker /var/run/docker.sock

		echo "Done!"
		break
	else
		echo "/var/run/docker.sock not found! Sleeping for $delay second(s)..."
		sleep $delay
	fi
done

echo "configuredocker script done"
