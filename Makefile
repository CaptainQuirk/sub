COMMANDS := $(MAKEFILE_LIST)

lint: ## Lint code with shellcheck
	@echo "\033[1m  RUNNING SHELLCHECK\033[0m"
	@docker-compose -f .docker/docker-compose.yml run --rm shellcheck libexec/*
	@echo "\033[32;1m晴 \033[1mSHELLCHECK OK\033[0m"

