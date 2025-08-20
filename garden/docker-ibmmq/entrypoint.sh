#!/bin/bash

# Start MQ normally
/opt/mqm/bin/runmqdevserver &

# Wait for the queue manager to start
sleep 10

# Apply MQSC configuration
echo "Applying MQSC configuration..."
runmqsc QM1 < /etc/mqm/configure.mqsc

# Keep container running
tail -f /dev/null
