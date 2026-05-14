#!/usr/bin/env bash
echo "Pushing agent memories to GitHub..."
AGENTS_BASE="$HOME/.letta/agents"
TIMESTAMP=$(date +%y%m%d%H%M)

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

echo "Dumping PostgreSQL database to OneDrive..."
CONTAINER="letta-db"
DB_USER="letta"
DB_NAME="letta"
DIR="$HOME/Library/CloudStorage/OneDrive-TheUniversityofSouthDakota/AI"
FILE="$DIR/lettaDB$TIMESTAMP.sql.gz"
if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
    echo "Error: Docker container $CONTAINER is not running. Skipping DB backup."
    exit 1
fi
docker exec -t "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$FILE"
# Clean up old database backups (older than 30 days)
find "$DIR" -type f -name "*.sql.gz" -mtime +30 -delete
echo "Database saved to $FILE"
