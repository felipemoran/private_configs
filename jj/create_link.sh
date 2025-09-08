#!/bin/bash
# create_link.sh

label="$1"         # e.g. "checkout abc123"
command="$2"       # e.g. "git checkout abc123"
encoded_cmd=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$command'''))")

# Assuming command_handler.sh is at ~/scripts/command_handler.sh
echo -e "\033]8;;file://$HOME/scripts/command_handler.sh?cmd=$encoded_cmd\033\\$label\033]8;;\033\\"

