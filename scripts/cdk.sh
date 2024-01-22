#!/bin/bash

# Get the directory of the currently executing script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Include the configuration file
source "$SCRIPT_DIR/assume.sh"

echo "Running CDK with passing parameters"
npx cdk "$@"
