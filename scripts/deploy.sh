#!/usr/bin/env bash
set -euo pipefail

SERVER="nox-prod"  # SSH alias (configure in ~/.ssh/config)
REMOTE_DIR="/home/ubuntu/nox"
COMPONENT="${1:-all}"

deploy_backend() {
    echo "deploying backend..."
    rsync -avz --delete \
        --exclude '__pycache__' \
        --exclude '.pytest_cache' \
        --exclude '*.pyc' \
        app/ "$SERVER:$REMOTE_DIR/app/"

    rsync -avz pyproject.toml uv.lock "$SERVER:$REMOTE_DIR/"

    echo "installing dependencies..."
    ssh "$SERVER" "cd $REMOTE_DIR && ~/.local/bin/uv sync --quiet"

    echo "updating systemd service..."
    ssh "$SERVER" "sudo cp $REMOTE_DIR/scripts/nox.service /etc/systemd/system/ && sudo systemctl daemon-reload"

    echo "running migrations..."
    ssh "$SERVER" "cd $REMOTE_DIR && ~/.local/bin/uv run python -m app.db.migrate"

    echo "restarting service..."
    ssh "$SERVER" "sudo systemctl restart nox"

    echo "backend deployed."
}

deploy_scripts() {
    echo "deploying scripts..."
    rsync -avz scripts/ "$SERVER:$REMOTE_DIR/scripts/"
    echo "scripts deployed."
}

case "$COMPONENT" in
    backend|be)
        deploy_backend
        ;;
    scripts)
        deploy_scripts
        ;;
    all)
        deploy_scripts
        deploy_backend
        ;;
    *)
        echo "usage: deploy.sh [backend|scripts|all]"
        exit 1
        ;;
esac
