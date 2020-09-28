.PHONY: list clean

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

build: ## Build local images
	docker-compose -f docker-compose.yml -f docker-compose.override.yml build

run: ## Launch local
	docker-compose -f docker-compose.yml -f docker-compose.override.yml up --remove-orphans --exit-code-from php

down: ## Stop & remove local
	docker-compose -f docker-compose.yml stop && docker-compose -f docker-compose.yml rm

help: ## Display Makefile Rules
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
