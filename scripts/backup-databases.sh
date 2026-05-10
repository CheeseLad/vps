#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

if [ -z "$DISCORD_WEBHOOK_URL" ]; then
  echo "ERROR: DISCORD_WEBHOOK_URL is not set"
  exit 1
fi

declare -A CONTAINERS
declare -A COMMANDS
declare -A OUTPUTS

BACKUP_DIR="/home/debian/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Service definitions
CONTAINERS["listmonk"]="listmonk_db"
COMMANDS["listmonk"]="pg_dump listmonk -U listmonk"
OUTPUTS["listmonk"]="$BACKUP_DIR/listmonk/listmonk_postgres_$TIMESTAMP.sql"

CONTAINERS["plausible-events"]="plausible-plausible_db-1"
COMMANDS["plausible-events"]="pg_dump plausible_db -U postgres"
OUTPUTS["plausible-events"]="$BACKUP_DIR/plausible/plausible_postgres_$TIMESTAMP.sql"

CONTAINERS["plausible-clickhouse"]="plausible-plausible_events_db-1"
COMMANDS["plausible-clickhouse"]="clickhouse-backup create"
OUTPUTS["plausible-clickhouse"]="$BACKUP_DIR/plausible/plausible_clickhouse_$TIMESTAMP.sql"

run_backup() {
  local name="$1"
  local container="${CONTAINERS[$name]}"
  local command="${COMMANDS[$name]}"
  local output_file="${OUTPUTS[$name]}"
  local retention_dir
  retention_dir="$(dirname "$output_file")"

  mkdir -p "$retention_dir"

  # Run docker exec
  docker exec "$container" sh -c "$command" > "$output_file"

  # Cleanup old backups
  find "$retention_dir" -type f -mtime +7 -exec rm -f {} \;

  echo "Old backups in '$retention_dir' have been cleaned up."

  # Check result
  if [ -s "$output_file" ]; then
    size=$(du -h "$output_file" | cut -f1)
    echo "$name Backup successful ($size)"
    send_webhook "$name" "SUCCEEDED" "$output_file" "$size"
  else
    echo "$name Backup failed"
    rm -f "$output_file"
    send_webhook "$name" "FAILED" "$output_file" "0B"
  fi
}

# Function to send Discord notification
send_webhook() {
  local service_name=$1
  local status=$2
  local file=$3
  local size=$4

  local icon=""
  if [ "$status" == "SUCCEEDED" ]; then
    icon=":white_check_mark:"
  else
    icon=":x:"
  fi

  JSON='{
    "content": "'"$icon"' `'"$service_name"'` backup has **'"$status"'**\nFile: `'"$file"'`\nSize: `'"$size"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`"
  }'

  curl -X POST \
    -H "Content-Type: application/json" \
    -d "$JSON" \
    "${DISCORD_WEBHOOK_URL}"
}

for service in "${!CONTAINERS[@]}"; do
  run_backup "$service"
done