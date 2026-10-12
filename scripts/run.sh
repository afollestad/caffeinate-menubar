#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

"$repo_root/scripts/build.sh"

# `-x` matches case-sensitively, so `/usr/bin/caffeinate` processes are never touched.
if pgrep -x "$app_name" >/dev/null; then
  pkill -x "$app_name"
  attempt=0
  while pgrep -x "$app_name" >/dev/null && [ "$attempt" -lt 50 ]; do
    sleep 0.1
    attempt=$((attempt + 1))
  done
  if pgrep -x "$app_name" >/dev/null; then
    pkill -9 -x "$app_name"
  fi
fi

open "$(app_path debug)"
