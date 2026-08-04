.DEFAULT_GOAL := help

.PHONY: help configure up down reset ps logs health validate smoke \
	drill-traffic-stop drill-broker-outage recover

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

configure: ## Create a local .env file when one does not exist
	@test -f .env || cp .env.example .env

up: configure ## Start the complete lab and wait for healthy services
	docker compose up -d --wait

down: ## Stop the lab without deleting stored data
	docker compose down --remove-orphans

reset: ## Stop the lab and delete its local Docker volumes
	docker compose down --volumes --remove-orphans

ps: ## Show service state
	docker compose ps

logs: ## Follow logs for all services
	docker compose logs --follow --tail=100

health: ## Run the fast NOC health check
	./iot-healthcheck.sh

validate: ## Validate Compose, Prometheus, Alertmanager, JSON, and shell
	./scripts/validate.sh

smoke: ## Run endpoint and end-to-end MQTT integration tests
	./scripts/smoke-test.sh

drill-traffic-stop: ## Simulate silent IoT telemetry
	./scripts/drill.sh traffic-stop

drill-broker-outage: ## Simulate an MQTT broker outage
	./scripts/drill.sh broker-outage

recover: ## Recover services after a fault drill
	./scripts/drill.sh recover
