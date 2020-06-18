#  ___   ___   __    _     ____  ___        
# | | \ / / \ / /`  | |_/ | |_  | |_)       
# |_|_/ \_\_/ \_\_, |_| \ |_|__ |_| \       
#  __    ___   _      ___   ___   __   ____ 
# / /`  / / \ | |\/| | |_) / / \ ( (` | |_  
# \_\_, \_\_/ |_|  | |_|   \_\_/ _)_) |_|__ 
#

.PHONY: restart
restart: down up

.PHONY: up
up: pull build compose-up

.PHONY: up-prod
up-prod: pull build-prod compose-up

.PHONY: down
down: compose-down

.PHONY: pull
pull:
	@docker-compose pull

.PHONY: compose-up
compose-up:
	@docker-compose -f docker-compose.yml up -d --build

.PHONY: compose-down
compose-down:
	@docker-compose -f docker-compose.yml down

#   __    ___   ___  
#  / /\  | |_) | |_) 
# /_/--\ |_|   |_|   
#

NPM_CACHE := $(shell npm get cache)

.PHONY: clean
clean:
	@if [ ! -d "./node_modules" ]; \
		then echo "./node_molules needs to be present. Aborting. Run 'npm i' first."; \
		exit 1; \
		fi
	@echo "Cleaning crew, coming through..."
	@echo "Running 'npm run clean'"
	@npm run clean
	@echo "Removing elm-stuff and node_modules folders"
	@rm -rf ./{elm-stuff,node_modules} || true
	@echo -n "WARNING: the next operation will delete the NPM cache at $(NPM_CACHE) - type 'y' to continue: "
	@read confirm; \
	      	if [ "$$confirm" = "y" ]; \
		then echo "Removing NPM cache."; \
		rm -rf "$(NPM_CACHE)" || true; \
		else echo "Skipping removal of NPM cache"; \
		fi
	@echo -n "WARNING: the next operation will delete the package-lock.json file - type 'y' to continue: "
	@read confirm; \
		if [ "$$confirm" = "y" ]; \
	       	then echo "Removing package-lock.json."; \
	       	rm ./package-lock.json || true; \
	       	else echo "Skipping removal of package-lock.json"; \
	       	fi
	@echo "nice and shiny; don't forget to run 'npm install'"

.PHONY: build
build:
	NODE_ENV=development npm run build

.PHONY: build-prod
build-prod:
	NODE_ENV=production npm run build-prod

.PHONY: test
test:
	@elm-format --validate src/ tests/
	@elm-test

.PHONY: format
format:
	@elm-format --yes src/ tests/

.PHONY: bump-deps
bump-deps: clean
	@echo "Bumping current dependencies."
	@npx npm-check-updates -u
	@echo "Bumping Elm dependencies."
	@npx elm-json upgrade --yes
	@echo "Installing dependencies."
	@npm i
	@echo "Attempting to automatically fix vulnerabilities."
	@npm audit fix
	@echo "Dependencies upgraded. Enjoy."

.PHONY: bump-deps-test
bump-deps-test: bump-deps
	@echo "Running cypress tests"
	@npm run test:cy

