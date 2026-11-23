# Linux process supervision lab

Explore bounded restarts, graceful termination, and duplicate-instance protection
using Bash and disposable worker processes.

## Run

Requirements: Linux, Bash 4+, Make, and ShellCheck.

```sh
make test
```

The drill injects one worker failure, observes its replacement, sends SIGTERM to
the supervisor, and verifies the child exits and the lock directory is released.
It also checks exhausted restart budgets, successful completion, and invalid inputs.

## Try a manual session

```sh
state=$(mktemp -d)
bash supervise.sh "$state" fail-once &
supervisor=$!
cat "$state/events.log"
kill -TERM "$supervisor"
wait "$supervisor"
cat "$state/events.log"
rm -r "$state"
```

Wait for a heartbeat before sending SIGTERM. `MAX_ATTEMPTS=3` bounds total starts,
including the first start. Exit 7 means the fixture exhausted its retry budget;
64 is an invalid invocation and 73 indicates an existing lock.

The lock is an atomic directory. After an uncatchable kill or machine failure,
inspect process ownership before removing a stale lock. Use a fresh private state
directory for each experiment. A real service manager also provides boot integration,
resource controls, privilege separation, and logging policy.

[Validation](VALIDATION.md) · [Bash signal handling](https://www.gnu.org/software/bash/manual/html_node/Signals.html)
