#!/bin/bash

# JJ Divergent Commit Resolver
# Usage: ./jj_divergent.sh [--safe]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if ts-node is available
if ! command -v ts-node &> /dev/null; then
    echo "Error: ts-node is not installed. Please install it with:"
    echo "npm install -g ts-node typescript"
    exit 1
fi

# Check if we're in a jj repository
if ! jj status &> /dev/null; then
    echo "Error: Not in a jj repository or jj is not available"
    exit 1
fi

# Run the TypeScript tool with all passed arguments
ts-node "$SCRIPT_DIR/jj_divergent_resolver.ts" "$@"
