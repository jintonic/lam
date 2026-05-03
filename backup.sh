#!/bin/sh
CONTAINER="letta-db"
DB_USER="letta"
DB_NAME="letta"
DIR="$HOME/Library/CloudStorage/OneDrive-TheUniversityofSouthDakota/AI"
TIMESTAMP=$(date +%F_%H%M)
FILE="$DIR/letta_memory_$TIMESTAMP.sql.gz"

docker exec -t $CONTAINER pg_dump -U $DB_USER $DB_NAME | gzip > "$FILE"

find "$DIR" -type f -name "*.sql.gz" -mtime +30 -delete
