.PHONY: install dev demo test lint seed seed-reset docker-up docker-down openapi

install:
	pip install -r requirements-dev.txt

dev:
	uvicorn app.main:app --reload --port 8000

demo:            ## run with an in-memory DB + demo data, no installs needed besides pip
	MONGODB_URL=mongomock:// SEED_ON_STARTUP=true uvicorn app.main:app --reload --port 8000

test:
	pytest -q

lint:
	ruff check app tests

seed:
	python -m scripts.seed_data

seed-reset:
	python -m scripts.seed_data --reset

openapi:
	python -m scripts.export_openapi

docker-up:
	docker compose up -d --build

docker-down:
	docker compose down
