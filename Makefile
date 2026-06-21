.PHONY: run-backend run-backend-prod run-ui migrate deploy deploy-be setup-nanomdm logs test lint fmt health

# local dev server
run-backend:
	ENV=dev uv run uvicorn app.main:app --reload --port 8000

# production server (local)
run-backend-prod:
	uv run gunicorn app.main:app -w 3 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000

# open iOS project in Xcode
run-ui:
	@echo "Open ios/Nox.xcodeproj in Xcode and run on simulator"
	open ios/Nox.xcodeproj

# run database migrations
migrate:
	ENV=dev uv run python -m app.db.migrate

# deploy everything to prod
deploy:
	./scripts/deploy.sh

# deploy backend only
deploy-be:
	./scripts/deploy.sh backend

# set up nanomdm on server
setup-nanomdm:
	./scripts/setup_nanomdm.sh

# tail production logs
logs:
	ssh nox-prod 'sudo journalctl -u nox -f'

# run tests
test:
	ENV=dev uv run pytest

# lint with ruff
lint:
	uv run ruff check app/

# format with ruff
fmt:
	uv run ruff format app/

# check health endpoint
health:
	curl -s http://localhost:8000/health | python -m json.tool
