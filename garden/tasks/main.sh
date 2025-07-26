#!/bin/bash

: '

Main orchestrator for the garden project.

Control Panel > Task Scheduler > Create > Triggered Task > User-defined script. 

Set User to 'root' and set the Event as 'Boot-up',
go to Task Settings and paste the following in User-defined script:

bash /volume1/docker/projects/garden/tasks/main.sh

'

scriptdir="$(dirname -- "$BASH_SOURCE")"
groupnamedocker="dockerlimited"

$scriptdir/filesystem.sh $groupnamedocker

$scriptdir/freeports.sh

$scriptdir/configuredocker.sh $groupnamedocker

sudo docker compose -f /volume1/docker/projects/garden/docker-compose.yaml up -d
