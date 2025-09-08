#!/usr/bin/env bash
# vsgoto-cursor.sh
# Usage: vsgoto-cursor.sh <file> [line] [column]

set -euo pipefail

# Enable debug logging if DEBUG environment variable is set
if [[ "${DEBUG:-}" == "1" ]]; then
  set -x
  echo "Debug: Starting script with args: $*" >&2
fi

CURSOR_CODE="/Applications/Cursor.app/Contents/Resources/app/bin/code"

usage() {
  echo "Usage: $(basename "$0") <file> [line] [column]" >&2
  exit 2
}

FILE="${1:-}"; LINE="${2:-0}"; COL="${3:-0}"
[[ -z "$FILE" ]] && usage

[[ "${DEBUG:-}" == "1" ]] && echo "Debug: FILE='$FILE', LINE='$LINE', COL='$COL'" >&2

# --- find nearest *.code-workspace by walking upwards ---
find_workspace_up() {
  local dir
  dir="$(realpath "$(dirname "$FILE")")"
  [[ "${DEBUG:-}" == "1" ]] && echo "Debug: Looking for workspace starting from: $dir" >&2
  while :; do
    [[ "${DEBUG:-}" == "1" ]] && echo "Debug: Checking directory: $dir" >&2
    ws="$(find "$dir" -maxdepth 1 -type f -name '*.code-workspace' -print -quit 2>/dev/null || true)"
    if [[ -n "${ws:-}" ]]; then
      [[ "${DEBUG:-}" == "1" ]] && echo "Debug: Found workspace: $ws" >&2
      echo "$ws"
      return 0
    fi
    [[ "$dir" == "/" ]] && { [[ "${DEBUG:-}" == "1" ]] && echo "Debug: Reached root, no workspace found" >&2; return 1; }
    parent="$(dirname "$dir")"
    [[ "$parent" == "$dir" ]] && { [[ "${DEBUG:-}" == "1" ]] && echo "Debug: Cannot go higher, stopping" >&2; return 1; }
    dir="$parent"
  done
}

WORKSPACE="$(find_workspace_up || true)"
GOTO_ARG="${FILE}:${LINE}:${COL}"

[[ "${DEBUG:-}" == "1" ]] && echo "Debug: WORKSPACE='${WORKSPACE:-}', GOTO_ARG='$GOTO_ARG'" >&2

if [[ -n "${WORKSPACE:-}" ]]; then
  [[ "${DEBUG:-}" == "1" ]] && echo "Debug: Opening with workspace: $CURSOR_CODE '$WORKSPACE' --goto '$GOTO_ARG'" >&2
  exec "$CURSOR_CODE" "$WORKSPACE" --goto "$GOTO_ARG"
else
  [[ "${DEBUG:-}" == "1" ]] && echo "Debug: Opening without workspace: $CURSOR_CODE '$(dirname "$FILE")' --goto '$GOTO_ARG'" >&2
  exec "$CURSOR_CODE" "$(dirname "$FILE")" --goto "$GOTO_ARG"
fi
