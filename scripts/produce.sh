#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Include the configuration file
source "$SCRIPT_DIR/assume.sh"

echo "Running PUT dummy data to Kinesis Data Streams"
node main.js "$@"
