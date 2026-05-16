#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

TIMESTAMP=$(date +%y%m%d%H%M)

echo "========================================="
echo "Starting Unified Letta Backup Routine"
echo "========================================="

# Detect the operating system
# macOS returns 'Darwin', Linux returns 'Linux'
OS_TYPE=$(uname -s)

if [ "$OS_TYPE" = "Darwin" ]; then
  # ---------------------------------------------------------------------
  # MAC WORKFLOW: ONLY BACK UP MEMORIES TO GITHUB
  # ---------------------------------------------------------------------
  echo "Environment: macOS detected. Initiating memory pushes..."

  AGENTS_BASE="$HOME/.letta/agents"

  if [ ! -d "$AGENTS_BASE" ]; then
    echo "Error: Letta agents directory not found at $AGENTS_BASE. Quitting."
    exit 1
  fi

  for AGENT_PATH in "$AGENTS_BASE"/*; do
    [ ! -d "$AGENT_PATH/memory" ] && continue
    AGENT_ID=$(basename "$AGENT_PATH")

    cd "$AGENT_PATH/memory" || continue

    if [ ! -d ".git" ]; then
      echo "Warning: $AGENT_ID/memory is not a git repository. Skipping."
      continue
    fi

    if ! git remote | grep -q "github"; then
      echo "Warning: No 'github' remote for $AGENT_ID. Skipping push."
      continue
    fi

    echo "Backing up MemFS for $AGENT_ID"
    git add .
    git commit -m "Manual backup at $TIMESTAMP" --allow-empty
    git push github master
  done

  echo "Memory syncing complete."

else
  # ---------------------------------------------------------------------
  # HETZNER / LINUX WORKFLOW: ONLY BACK UP POSTGRES TO CURRENT FOLDER
  # ---------------------------------------------------------------------
  echo "Environment: Linux detected (Hetzner). Initiating database dump..."

    # Load production credentials from the local .env if available
    if [ -f "./.env" ]; then
      export $(grep -v '^#' ./.env | xargs)
    elif [ -f "$HOME/lam/.env" ]; then
      export $(grep -v '^#' "$HOME/lam/.env" | xargs)
    fi

    DB_CONTAINER="letta-db"
    DB_USER="letta"
    DB_NAME="letta"

    # Target file is written directly to the execution directory
    FILE="./lettaDB$TIMESTAMP.sql.gz"

    if ! docker ps --format '{{.Names}}' | grep -q "^$DB_CONTAINER$"; then
      echo "Error: Database container '$DB_CONTAINER' is not running. Aborting DB dump."
      exit 1
    fi

    echo "Exporting database state to $FILE..."
    # No sudo required. Authenticates via environmental variables inside the stream.
    docker exec -t -e PGPASSWORD="$DB_PASSWORD" "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$FILE"

    echo "Database successfully saved to current folder."
fi

echo "========================================="
echo "Backup process complete."
echo "========================================="
