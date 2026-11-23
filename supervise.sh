#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 2 ]]; then echo 'usage: bash supervise.sh STATE_DIR steady|fail-once|always-fail|complete' >&2; exit 64; fi
state_dir=$1
mode=$2
attempt_limit=${MAX_ATTEMPTS:-3}
case "$mode" in steady|fail-once|always-fail|complete) ;; *) echo 'invalid worker mode' >&2; exit 64 ;; esac
if [[ ! $attempt_limit =~ ^[1-9][0-9]*$ ]] || (( attempt_limit > 10 )); then
  echo 'MAX_ATTEMPTS must be between 1 and 10' >&2; exit 64
fi
umask 077
mkdir -p -- "$state_dir"
state_dir=$(cd -- "$state_dir" && pwd)
if ! mkdir "$state_dir/supervisor.lock" 2>/dev/null; then echo 'another supervisor owns this state directory' >&2; exit 73; fi
child_pid=''
stopping=0
cleanup() {
  trap - EXIT TERM INT
  if [[ -n $child_pid ]]; then
    kill -TERM "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
  rm -f -- "$state_dir/child.pid" "$state_dir/supervisor.pid"
  rmdir "$state_dir/supervisor.lock"
}
request_stop() {
  stopping=1
  if [[ -n $child_pid ]]; then kill -TERM "$child_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap request_stop TERM INT
printf '%s\n' "$$" > "$state_dir/supervisor.pid"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for ((attempt=1; attempt<=attempt_limit; attempt++)); do
  (( stopping == 0 )) || exit 0
  bash "$script_dir/worker.sh" "$state_dir" "$mode" &
  child_pid=$!
  printf '%s\n' "$child_pid" > "$state_dir/child.pid"
  if wait "$child_pid"; then status=0; else status=$?; fi
  if (( stopping )); then exit 0; fi
  child_pid=''
  printf 'worker_exit %s attempt %s\n' "$status" "$attempt" >> "$state_dir/events.log"
  if (( status == 0 )); then exit 0; fi
  if (( attempt == attempt_limit )); then exit "$status"; fi
  sleep 0.02
done
