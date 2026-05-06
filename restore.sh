#!/bin/sh
DIR="$HOME/Library/CloudStorage/OneDrive-TheUniversityofSouthDakota/AI"
CONTAINER="letta-db"
DB_USER="letta"
DB_NAME="letta"

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
echo "Restore complete."
