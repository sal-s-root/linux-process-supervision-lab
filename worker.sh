#!/usr/bin/env bash
set -euo pipefail
state_dir=$1
mode=$2
printf 'worker_start %s\n' "$$" >> "$state_dir/events.log"
stop() { printf 'worker_stop %s\n' "$$" >> "$state_dir/events.log"; exit 0; }
trap stop TERM INT
case "$mode" in
  complete) exit 0 ;;
  always-fail) exit 7 ;;
  fail-once)
    if mkdir "$state_dir/failure-injected" 2>/dev/null; then
      printf 'failure_injected %s\n' "$$" >> "$state_dir/events.log"
      exit 7
    fi ;;
esac
while :; do
  printf '%s\n' "$$" > "$state_dir/heartbeat"
  sleep 0.02
done
