# Copyright (c) 2021 Target Brands, Inc. All rights reserved.
#
# Use of this source code is governed by the LICENSE file in this repository.

# Set the default goal (help) if no targets
# were specified on the command line.
#
# Usage: `make`
.DEFAULT_GOAL := help

# The 'help' target will scan the Makefile
# for valid targets and return them
# in a formatted table.
#
# Note: it expects the pattern for each
# target entry to follow
#
# <target>: ## <description of target>
#
# Usage: `make help`
.PHONY: help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sed -n 's/^\(.*\): \(.*\)##\(.*\)/\1^\3/p' \
	| column -t -s^

#  ___   ___   __    _     ____  ___        
# | | \ / / \ / /`  | |_/ | |_  | |_)       
# |_|_/ \_\_/ \_\_, |_| \ |_|__ |_| \       
#  __    ___   _      ___   ___   __   ____ 
# / /`  / / \ | |\/| | |_) / / \ ( (` | |_  
# \_\_, \_\_/ |_|  | |_|   \_\_/ _)_) |_|__ 
#

# The `restart` target is intended to destroy and
# create the local Docker compose stack.
#
# Usage: `make restart`
.PHONY: restart
restart: down up ## Restart the local docker-compose stack

# The `up` target is intended to create
# the local Docker compose stack.
#
# Usage: `make up`
.PHONY: up
up: pull build compose-up ## Create the local docker-compose stack

# The `up-prod` target is intended to create
# the local Docker compose stack with the UI compiled
# for production.
#
# Usage: `make up`
.PHONY: up-prod
up-prod: pull build-prod compose-up ## Create the local docker-compose stack (prod)

# The `down` target is intended to destroy
# the local Docker compose stack.
#
# Usage: `make down`
.PHONY: down
down: compose-down ## Destroy the local docker-compose stack

# The `pull` target is intended to pull all
# images for the local Docker compose stack.
#
# Usage: `make pull`
.PHONY: pull
pull: ## Pull all images for the local docker-compose stack
	@echo -e "\n### Pulling images for docker-compose stack"
	@docker-compose pull

# The `compose-up` target is intended to build and create
# containers for the local Docker compose stack.
#
# Usage: `make compose-up`
.PHONY: compose-up
compose-up: ## Build and create containers for local docker-compose stack
	@echo -e "\n### Creating containers for docker-compose stack"
	@docker-compose -f docker-compose.yml up -d --build

# The `compose-down` target is intended to destroy
# all containers for the local Docker compose stack.
#
# Usage: `make compose-down`
.PHONY: compose-down
compose-down: ## Destroy all containers for local docker-compose stack
	@echo -e "\n### Destroying containers for docker-compose stack"
	@docker-compose -f docker-compose.yml down

#   __    ___   ___  
#  / /\  | |_) | |_) 
# /_/--\ |_|   |_|   
#

# Declare variable to hold location of local npm cache
NPM_CACHE := $(shell npm get cache)

# The `clean` target is intended to clean
# local NPM and Elm dependencies.
#
# Usage: `make clean`
.PHONY: clean
clean: ## Clean local NPM and Elm dependencies
	@if [ ! -d "./node_modules" ]; \
		then echo -e "\n### ./node_modules not found - run 'npm install' first"; \
		exit 1; \
		fi
	@echo -e "\n### Running 'npm run clean'"
	@npm run clean
	@echo -e "\n### Removing elm-stuff and node_modules folders"
	@rm -rf ./{elm-stuff,node_modules} || true
	@echo "WARNING: the next operation will delete the NPM cache at $(NPM_CACHE) \
	- do you want to continue? (y/N)"
	@read CONFIRM && \
	case $$CONFIRM in \
		y|Y|YES|yes|Yes) \
			echo "### Removing NPM cache" && \
			rm -rf "$(NPM_CACHE)" || true;; \
		*) echo "### Skipping removal of NPM cache";; \
	esac
	@echo "WARNING: the next operation will delete the package-lock.json file \
	- do you want to continue (y/N)"
	@read CONFIRM && \
	case $$CONFIRM in \
		y|Y|YES|yes|Yes) \
			echo "### Removing package-lock.json." && \
	       	rm ./package-lock.json || true;; \
		*) echo "### Skipping removal of package-lock.json";; \
	esac
	@echo -e "\n### Nice and shiny; don't forget to run 'npm install'"

# The `build` target is intended to build
# the UI in development mode.
#
# Usage: `make build`
.PHONY: build
build: ## Build the UI in development mode
	@echo -e "\n### Building UI for development"
	NODE_ENV=development npm run build

# The `build-prod` target is intended to build
# the UI in production mode.
#
# Usage: `make build-prod`
.PHONY: build-prod
build-prod: ## Build the UI in production mode
	@echo -e "\n### Building UI for production"
	NODE_ENV=production npm run build-prod

# The `test` target is intended to run
# the tests for the Elm source code.
#
# Usage: `make test`
.PHONY: test
test: format-validate ## Test the Elm source code
	@echo -e "\n### Testing Elm source code"
	@elm-test

# The `test-cypress` target is intended to run
# the Cypress tests for the UI.
#
# Usage: `make test-cypress`
.PHONY: test-cypress
test-cypress: ## Run Cypress tests
	@echo -e "\n### Running Cypress tests"
	@npm run test:cy

# The `format-validate` target is intended to
# check the format of the Elm source code.
#
# Usage: `make format-validate`
.PHONY: format-validate
format-validate: ## Validate Elm source code formatting
	@echo -e "\n### Validating Elm source code formatting"
	@elm-format --validate src/ tests/
	
# The `format` target is intended to
# format the Elm source code.
#
# Usage: `make format`
.PHONY: format
format: ## Format the Elm source code
	@echo -e "\n### Formatting Elm source code"
	@elm-format --yes src/ tests/

# The `bump-deps-npm` target is intended to
# upgrade the NPM dependencies
#
# Usage: `make bump-deps-npm`
.PHONY: bump-deps-npm
bump-deps-npm: ## Bump NPM dependencies
	@echo -e "\n### Bumping NPM dependencies"
	@npx npm-check-updates -u

# The `bump-deps-elm` target is intended to
# upgrade the Elm dependencies
#
# Usage: `make bump-deps-elm`
.PHONY: bump-deps-elm
bump-deps-elm: ## Bump Elm dependencies
	@echo -e "\n### Bumping Elm dependencies"
	@npx elm-json upgrade --yes

# The `bump-deps` target is intended to
# upgrade the NPM and Elm dependencies
#
# Usage: `make bump-deps`
.PHONY: bump-deps
bump-deps: clean bump-deps-npm bump-deps-elm ## Bump NPM and Elm dependencies
	@echo -e "\n### Re-installing dependencies"
	@npm install
	@echo -e "\n### Attempting to automagically fix vulnerabilities"
	@npm audit fix
	@echo -e "\n### Dependencies upgraded - enjoy"

# The `bump-deps-test` target is intended to
# upgrade NPM and Elm dependencies followed
# by running Cypress tests to validate that
# the dependency upgrades didn't introduce issues.
#
# Usage: `make bump-deps-test`
.PHONY: bump-deps-test
bump-deps-test: bump-deps test-cypress ## Bump dependencies and run Cypress tests
