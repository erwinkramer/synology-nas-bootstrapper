#!/bin/bash

: '

Main shutdown orchestrator for the garden project.

Control Panel > Task Scheduler > Create > Triggered Task > User-defined script. 

Set User to 'root' and set the Event as 'Shutdown',
go to Task Settings and paste the following in User-defined script:

bash /volume1/docker/projects/garden/tasks/main-shutdown.sh

'

docker compose -f /volume1/docker/projects/garden/docker-compose.yaml stop -t 60
