# Shared setup for scripts/*.sh; source it, don't execute it.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"

app_name=Caffeinate

# The assembled bundle for a build configuration (`debug` or `release`). Release builds put its dSYM at "<bundle>.dSYM".
app_path() {
  echo "$repo_root/.build/app/$1/$app_name.app"
}

# Runs `swift <args>`, logging raw output to .build/logs/ and condensing it with xcsift when installed.
# Set NO_XCSIFT=1 for raw output.
swift_filtered() {
  if [ "${NO_XCSIFT:-0}" = 1 ] || ! command -v xcsift >/dev/null 2>&1; then
    swift "$@"
    return
  fi
  mkdir -p .build/logs
  local log=".build/logs/$1.log"
  swift "$@" 2>&1 | tee "$log" | xcsift -f toon -w
}
