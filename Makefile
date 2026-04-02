.PHONY: help up down server migrate test-server reset

# Default target
help:
	@echo "Ghostenger — local development commands"
	@echo ""
	@echo "  make up           Start PostgreSQL and Redis via Docker Compose"
	@echo "  make down         Stop and remove containers"
	@echo "  make server       Run the Vapor server (requires 'make up' first)"
	@echo "  make migrate      Run database migrations"
	@echo "  make test-server  Run server-side tests"
	@echo "  make reset        Wipe containers + volumes and start fresh"
	@echo ""

## Docker
up:
	docker compose up -d
	@echo "Waiting for services to be healthy..."
	@until docker compose exec postgres pg_isready -U ghost -d ghostenger > /dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL is ready."
	@until docker compose exec redis redis-cli ping > /dev/null 2>&1; do sleep 1; done
	@echo "Redis is ready."

down:
	docker compose down

reset:
	docker compose down -v
	docker compose up -d

## Server
server:
	cd Server && swift run App serve --hostname 0.0.0.0 --port 8080

migrate:
	cd Server && swift run App migrate

## Tests
test-server:
	cd Server && swift test
