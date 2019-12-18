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

.PHONY: clean
clean:
	@echo "cleaning crew, coming through..."
	@rm -rf ./{elm-stuff,node_modules}
	@npm run clean
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