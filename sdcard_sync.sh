#!/bin/bash
# Set your source and destination
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# source "$SCRIPT_DIR/.env" # Systemd now handles loading this via EnvironmentFile
LOGFILE="$SCRIPT_DIR/sync.log"
# Simplified logging function (no gawk timestamp)
log() {
    echo "$*" >> "$LOGFILE"
}
echo "Logging to $LOGFILE"
# Update PATH to include gawk
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Detect the operating system
OS=$(uname)


# Load .env file only on macOS
if [ "$OS" == "Darwin" ]; then

    ENV_FILE="$SCRIPT_DIR/.env"
    echo "macOS detected. Loading environment variables from $ENV_FILE"

    if [ -f "$ENV_FILE" ]; then
        log "macOS detected. Loading environment variables from $ENV_FILE"
        # Use 'set -a' to export all variables sourced from the file
        set -a
        source "$ENV_FILE"
        set +a
    else
        log "macOS detected, but $ENV_FILE not found. Relying on existing environment variables."
    fi
elif [ "$OS" == "Linux" ]; then
    log "Linux detected. Assuming environment variables are provided by the system (e.g., Systemd)."
fi


# Ensure required environment variables are set
if [ -z "$SOURCE" ] || [ -z "$DEST" ] || [ -z "$LOGFILE" ]; then
    log "Error: SOURCE, DEST, and LOGFILE environment variables must be set."
    log "Example usage: SOURCE=/path/to/source DEST=/path/to/dest LOGFILE=/path/to/log ./sdcard_sync.sh"
    exit 1
fi



# Add a separation header for each run
log ""
log ""
log ""
log "========================================="
log "Script run started at $(date)"
log "========================================="

# Log the start time
log "Sync started at $(date)"

# Cleanup function to delete .DS_Store and ._ files
cleanup_files() {
    local DIR=$1
    log "Cleaning up .DS_Store and ._ files in $DIR"
    find "$DIR" -name ".DS_Store" -delete -print | while read line; do log "$line"; done 2>&1
    find "$DIR" -name "._*" -delete -print | while read line; do log "$line"; done 2>&1
}

# Check if the destination is mounted
if [ "$OS" == "Darwin" ]; then
    # macOS: Check if the destination directory exists
    if [ -d "$DEST" ]; then
        log "Destination directory exists: $DEST"
    else
        log "Error: Destination directory $DEST does not exist or is not mounted."
        exit 1
    fi
elif [ "$OS" == "Linux" ]; then
    MAX_WAIT=10
    WAITED=0
    while ! grep -qs "[[:space:]]$MOUNT[[:space:]]" /proc/mounts; do
        if [ $WAITED -ge $MAX_WAIT ]; then
            log "Error: Destination directory $MOUNT did not mount after waiting."
            exit 1
        fi
        log "Waiting for $MOUNT to be mounted..."
        sleep 1
        WAITED=$((WAITED+1))
    done
    log "Destination directory exists and is mounted: $MOUNT"
else
    log "Unsupported operating system: $OS"
    exit 1
fi

# Cleanup source and destination directories
cleanup_files "$SOURCE"
cleanup_files "$DEST"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="Markdown"
}

# Show the rsync command that will be run
log "Running rsync command to check diffs..."

# Capture the dry-run output
dry_run_output=$(rsync -avn --itemize-changes --delete --no-perms --no-owner --no-group --chmod=a=rwx \
    --exclude="*Lucife*" \
    "$SOURCE/" "$DEST/" 2>&1)

# Log the captured dry-run output
echo "$dry_run_output" | while read line; do log "$line"; done
# Count the number of files transferred, deleted, and errors
files_transferred=$(echo "$dry_run_output" | grep -c '^>f')
files_deleted=$(echo "$dry_run_output" | grep -c '^*deleting')
rsync_errors=$(echo "$dry_run_output" | grep -i -c 'rsync error')

# Notify based on the result
if [ $rsync_errors -gt 0 ]; then
    send_telegram "❌ *Syncer*: Sync encountered errors. Check the log for details."
else
    send_telegram "🔄 *Syncer*: Sync work: $files_transferred files to transfer, $files_deleted to delete."
fi

# Start rsync
rsync_output=$(rsync -av --itemize-changes --delete --no-perms --no-owner --no-group --chmod=a=rwx \
    --exclude="*Lucife*" \
    "$SOURCE/" "$DEST/" 2>&1)

# Count the number of files transferred, deleted, and errors
files_transferred=$(echo "$rsync_output" | grep -c '^>f')
files_deleted=$(echo "$rsync_output" | grep -c '^*deleting')
rsync_errors=$(echo "$rsync_output" | grep -i -c 'rsync error')


# Notify based on the result
if [ $rsync_errors -gt 0 ]; then
    send_telegram "❌ *Syncer*: Sync encountered errors. Check the log for details."
elif [ $files_transferred -gt 0 ] && [ $files_deleted -gt 0 ]; then
    send_telegram "🔄 *Syncer*: Sync complete: $files_transferred files transferred, $files_deleted files deleted."
elif [ $files_transferred -gt 0 ]; then
    send_telegram "✅ *Syncer*: Sync complete: $files_transferred files transferred."
elif [ $files_deleted -gt 0 ]; then
    send_telegram "🗑️ *Syncer*: Sync complete: $files_deleted files deleted."
else
    send_telegram "ℹ️ *Syncer*: Sync complete: No files transferred or deleted."
fi

# Log rsync output
echo "$rsync_output" | while read line; do log "$line"; done

# Log the end time
log "Sync ended at $(date)"

# Add a separation footer for each run
log "========================================="
log "Script run ended at $(date)"
log "========================================="
