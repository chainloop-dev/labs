VERSION=$(shell git describe --tags --always)
# CHAINLOOP_TOKEN is required for testing and should be places in .env file
DOCKER_TEST_CMD=docker run --rm -it -w /code -v "${PWD}:/code" --env-file .env $(DOCKER_IMG) ./test/run.sh

.PHONY: build
# build
build:
	bundle exec bashly generate -e production
  
.PHONY: test
# test
test:
	./test/bats/bin/bats --print-output-on-failure test 

docker_test_on_ubuntu: DOCKER_IMG=node
docker_test_on_alpine: DOCKER_IMG=chainguard/bash
docker_test_on_ubi: DOCKER_IMG=redhat/ubi9
docker_test_on_ubuntu docker_test_on_alpine docker_test_on_ubi:
	@echo "\n\n### $@: Testing on $(DOCKER_IMG)"
	$(DOCKER_TEST_CMD)
docker_test: build docker_test_on_ubuntu
docker_test_all: build docker_test_on_ubuntu docker_test_on_alpine docker_test_on_ubi
docker_test_shell:
	docker run --rm -it -w /code -v "${PWD}:/code" node bash 

.PHONY: lint
# lint
lint:
	shellcheck  -s bash -S error src/lib/*.sh src/*.sh

# show help
help:
	@echo ''
	@echo 'Usage:'
	@echo ' make [target]'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-_0-9]+:/ { \
	helpMessage = match(lastLine, /^# (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 2, RLENGTH); \
			printf "\033[36m%-22s\033[0m %s\n", helpCommand,helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
