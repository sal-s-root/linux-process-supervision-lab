.PHONY: test
test:
	bash -n supervise.sh worker.sh tests/run.sh
	shellcheck supervise.sh worker.sh tests/run.sh
	bash tests/run.sh
