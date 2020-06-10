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
	@echo "cleaning crew, coming through..."
	@npm run clean
	@rm -rf ./{elm-stuff,node_modules} || true
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

.PHONY: upgrade-deps
upgrade-deps: clean
	@echo -n "WARNING: this next operation will delete the NPM cache at $(NPM_CACHE) - type 'yes' to continue: "
	@read confirm && [ "$$confirm" = "yes" ]
	@rm -rf "$(NPM_CACHE)" || true
	@echo "NPM cache deleted."
	@echo -n "WARNING: this next operation will delete the package-lock.json file - type 'yes' to continue: "
	@read confirm && [ "$$confirm" = "yes" ]
	@rm ./package-lock.json || true
	@echo "Bumping current dependencies."
	@npx npm-check-updates -u
	@echo "Installing dependencies."
	@npm i
	@echo "Attempting to automatically fix vulnerabilities."
	@npm audit fix
	@echo "Dependencies upgraded. Enjoy."

