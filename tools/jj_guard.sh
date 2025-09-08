#!/usr/bin/env bash
# Simple jj wrapper without flock: prevents concurrent runs using mkdir

LOCKDIR=/tmp/jj.lockdir

# Try to acquire lock
if mkdir "$LOCKDIR" 2>/dev/null; then
  # Ensure lock is released on exit
  trap 'rm -rf "$LOCKDIR"' EXIT
else
  echo "Another jj is already running" >&2
  exit 98
fi

# Run jj with given arguments
jj "$@"
