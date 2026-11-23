#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
lab_dir=$(mktemp -d)
supervisor_pid=''
cleanup() {
  if [[ -n $supervisor_pid ]]; then kill -TERM "$supervisor_pid" 2>/dev/null || true; wait "$supervisor_pid" 2>/dev/null || true; fi
  rm -rf -- "$lab_dir"
}
trap cleanup EXIT
wait_for() {
  local pattern=$1 file=$2
  for ((i=0; i<200; i++)); do
    if grep -q -- "$pattern" "$file" 2>/dev/null; then return 0; fi
    sleep 0.02
  done
  echo "timed out waiting for $pattern" >&2; return 1
}
bash supervise.sh "$lab_dir/complete" complete
[[ ! -d $lab_dir/complete/supervisor.lock ]]
printf 'PASS successful completion and lock cleanup\n'
if MAX_ATTEMPTS=3 bash supervise.sh "$lab_dir/exhausted" always-fail; then exit 1; else status=$?; fi
[[ $status == 7 && $(grep -c '^worker_start ' "$lab_dir/exhausted/events.log") == 3 ]]
[[ ! -d $lab_dir/exhausted/supervisor.lock ]]
printf 'PASS bounded restart budget\n'
bash supervise.sh "$lab_dir/recovery" fail-once & supervisor_pid=$!
wait_for 'failure_injected' "$lab_dir/recovery/events.log"
wait_for '[0-9]' "$lab_dir/recovery/heartbeat"
[[ $(grep -c '^worker_start ' "$lab_dir/recovery/events.log") == 2 ]]
child_pid=$(cat "$lab_dir/recovery/child.pid")
kill -TERM "$supervisor_pid"; wait "$supervisor_pid"; supervisor_pid=''
if kill -0 "$child_pid" 2>/dev/null; then echo 'worker survived shutdown' >&2; exit 1; fi
[[ ! -d $lab_dir/recovery/supervisor.lock ]]
grep -q '^worker_stop ' "$lab_dir/recovery/events.log"
printf 'PASS injected failure, restart, and graceful shutdown\n'
bash supervise.sh "$lab_dir/duplicate" steady & supervisor_pid=$!
wait_for '[0-9]' "$lab_dir/duplicate/heartbeat"
if bash supervise.sh "$lab_dir/duplicate" steady 2>/dev/null; then exit 1; else status=$?; fi
[[ $status == 73 ]]
kill -0 "$supervisor_pid"
kill -TERM "$supervisor_pid"; wait "$supervisor_pid"; supervisor_pid=''
printf 'PASS duplicate supervisor refusal\n'
if MAX_ATTEMPTS=0 bash supervise.sh "$lab_dir/invalid" steady 2>/dev/null; then exit 1; else [[ $? == 64 ]]; fi
if bash supervise.sh "$lab_dir/invalid" unknown 2>/dev/null; then exit 1; else [[ $? == 64 ]]; fi
printf 'PASS invalid configuration refusal\n'
