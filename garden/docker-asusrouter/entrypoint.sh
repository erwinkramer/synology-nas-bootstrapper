#!/bin/sh
set -e

SCRIPTS_DIR="/app/scripts"

if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "ERROR: No scripts directory found"
    exit 1
fi

# Run scripts
for pyfile in "$SCRIPTS_DIR"/*.py; do
    echo "$pyfile found, running now"
    exec python "$pyfile" || echo "ERROR running $pyfile"
done
