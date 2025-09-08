#!/bin/bash
# ~/scripts/command_handler.sh

# Extract query string
url="$1"
cmd=$(echo "$url" | sed -n 's/.*cmd=\(.*\)/\1/p' | xargs -0 python3 -c "import sys, urllib.parse as u; print(u.unquote(sys.stdin.read()))")

# Safety: confirm execution
echo "About to run: $cmd"
read -p "Run it? [y/N] " confirm
if [[ "$confirm" == "y" ]]; then
    eval "$cmd"
fi
