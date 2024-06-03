VERSION=$(shell git describe --tags --always)

.PHONY: build
# build
build:
	bundle exec bashly generate -e production
  
.PHONY: test
# test
test:
	./test/bats/bin/bats --print-output-on-failure test 

docker_test:
	docker run --rm -it -w /code -v "${PWD}:/code" node ./test/bats/bin/bats --print-output-on-failure test 

docker_test_on_alpine:
	docker run --rm -it -w /code -v "${PWD}:/code" chainguard/bash "./test/bats/bin/bats --print-output-on-failure test"

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
