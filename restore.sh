#!/bin/bash
# bash instead of sh must be used for associative array support
declare -A AGENT_IDS
AGENT_IDS["mandy"]="agent-75a17c6e-1841-4181-8c3d-6549d52db66a"
AGENT_IDS["tina"]="agent-8c86b66c-4c47-454e-837b-ae106bd4ea6d"

restore_memory() {
    local AGENT_NAME=$1
    local AGENT_ID=${AGENT_IDS[$AGENT_NAME]}
    local AGENT_DIR="$HOME/.letta/agents/$AGENT_ID"

    if [ ! -d "$AGENT_DIR" ]; then
        echo "Error: Agent directory $AGENT_DIR not found. Is Letta running and the ID correct?"
        exit 1
    fi

    echo "Restoring Git-backed MemFS for $AGENT_NAME ($AGENT_ID)..."
    cd "$AGENT_DIR/memory" || { echo "Error: Memory dir not found"; exit 1; }
    
    if [ -d ".git" ]; then
        if ! git remote get-url github >/dev/null 2>&1; then
            echo "Adding github remote..."
            git remote add github "git@github.com:jintonic/$AGENT_NAME.git"
        fi
        echo "Resetting MemFS to github/master..."
        git fetch github
        git reset --hard github/master
    else
        echo "Error: .git directory not found in $AGENT_DIR/memory."
        exit 1
    fi
}

# parsing arguments
INPUT=$1
DIR="$HOME/Library/CloudStorage/OneDrive-TheUniversityofSouthDakota/AI"

# Case A: Specific Agent Name
if [[ -n "${AGENT_IDS[$INPUT]}" ]]; then
    restore_memory "$INPUT"
    exit 0
# Case B: Path to a specific .sql.gz file
elif [[ -f "$INPUT" && "$INPUT" == *.sql.gz ]]; then
    FILE="$INPUT"
# Case C: No argument provided - find latest backup
elif [[ -z "$INPUT" ]]; then
    FILE=$(ls -t "$DIR"/*.sql.gz 2>/dev/null | head -n 1)
    if [ -z "$FILE" ]; then
        echo "Error: No backup files found in $DIR"
        exit 1
    fi
    echo "Using latest database backup: $FILE"
# Case D: Invalid Argument
else
    echo "Usage: ./restore.sh [mandy|tina|path/to/backup.sql.gz]"
    echo "If no argument is provided, the latest database backup in OneDrive will be used."
    exit 1
fi

# Database Restoration Logic (Shared by Case B and C)
CONTAINER="letta-db"
DB_USER="letta"
DB_NAME="letta"

echo "Stopping Letta application containers..."
docker stop letta letta-mcp

echo "Clearing database schema..."
docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

echo "Restoring $FILE to $CONTAINER..."
gunzip -c "$FILE" | docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME

echo "Starting Letta application containers..."
docker start letta letta-mcp
echo "Database restore complete."
