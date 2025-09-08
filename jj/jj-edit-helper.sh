#!/bin/bash

# jj-edit-helper.sh
# This script is called when clicking on a change ID in jj log output
# It will run 'jj edit -r <change_id>' to edit the clicked commit

# Check if a change ID was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <change_id>"
    echo "This script is meant to be called from hyperlinks in jj log output"
    exit 1
fi

CHANGE_ID="$1"

# Validate that the change ID looks reasonable (basic sanity check)
if [[ ! "$CHANGE_ID" =~ ^[a-z0-9]+$ ]]; then
    echo "Error: Invalid change ID format: $CHANGE_ID"
    exit 1
fi

echo "Editing commit with change ID: $CHANGE_ID"

# Execute jj edit command
exec jj edit -r "$CHANGE_ID"