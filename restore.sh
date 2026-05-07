#!/bin/sh
DIR="$HOME/Library/CloudStorage/OneDrive-TheUniversityofSouthDakota/AI"
CONTAINER="letta-db"
DB_USER="letta"
DB_NAME="letta"

# Function to handle memory restoration
restore_memory() {
    AGENT_NAME=$1
    if [ -z "$AGENT_NAME" ]; then
        echo "Error: Agent name (e.g., 'mandy') required for memory restoration."
        exit 1
    fi

    # Find the agent directory in ~/.letta/agents/
    # Note: We assume the agent is already registered and the directory exists
    # If the database was just restored, the Letta CLI should have created the folder structure
    AGENT_DIR=$(find "$HOME/.letta/agents" -maxdepth 1 -name "agent-*" -type d | head -n 1)

    if [ -z "$AGENT_DIR" ]; then
        echo "Error: No agent directory found in ~/.letta/agents/. Ensure Letta is started and agent is registered."
        exit 1
    fi

    echo "Restoring memory for agent in $AGENT_DIR..."
    cd "$AGENT_DIR/memory" || exit 1
    
    if [ -d ".git" ]; then
        if ! git remote get-url github >/dev/null 2>&1; then
            echo "Adding github remote..."
            git remote add github "git@github.com:jintonic/$AGENT_NAME.git"
        fi
        echo "Pulling from GitHub..."
        git fetch github
        git branch --set-upstream-to=github/master master
        git reset --hard github/master
    else
        echo "Error: .git directory not found in $AGENT_DIR/memory. Is it a git repo?"
        exit 1
    fi
}

# Check if we are restoring database or memory
if [ "$1" = "mandy" ]; then
    restore_memory "$1"
    exit 0
fi

# Database restoration logic
if [ -z "$1" ]; then
    # Find latest sql.gz file in the directory
    FILE=$(ls -t "$DIR"/*.sql.gz 2>/dev/null | head -n 1)
    if [ -z "$FILE" ]; then
        echo "Error: No backup files found in $DIR"
        exit 1
    fi
    echo "No file provided. Using latest: $FILE"
else
    FILE=$1
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE not found."
    exit 1
fi

echo "Stopping Letta application containers..."
docker stop letta letta-mcp

echo "Clearing database schema to avoid conflicts..."
docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

echo "Restoring $FILE to $CONTAINER/$DB_NAME..."
gunzip -c "$FILE" | docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME

echo "Starting Letta application containers..."
docker start letta letta-mcp
echo "Database restore complete."
