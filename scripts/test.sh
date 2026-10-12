#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [filter]" >&2
  exit 1
fi

swift_filtered test ${1:+--filter "$1"}
