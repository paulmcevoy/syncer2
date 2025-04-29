#!/bin/bash
# Set your source and destination
SOURCE="/Volumes/elements/other/"
DEST="/Volumes/SD256/MUSIC/other"
LOGFILE="$(dirname "$0")/sync.log"

#!/bin/bash

# Update PATH to include gawk
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Your script logic here

env > ~/launchd-env.log

# Ensure required environment variables are set
if [ -z "$SOURCE" ] || [ -z "$DEST" ] || [ -z "$LOGFILE" ]; then
    echo "Error: SOURCE, DEST, and LOGFILE environment variables must be set." | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
    echo "Example usage: SOURCE=/path/to/source DEST=/path/to/dest LOGFILE=/path/to/log ./sdcard_sync.sh" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
    exit 1
fi

# Detect the operating system
OS=$(uname)

# Add a separation header for each run
{
    echo "========================================="
    echo "Script run started at $(date)"
    echo "========================================="
} | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"

# Log the start time
echo "Sync started at $(date)" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
terminal-notifier -title "Syncer" -message "Sync started!" -sound default

# Cleanup function to delete .DS_Store and ._ files
cleanup_files() {
    local DIR=$1
    echo "Cleaning up .DS_Store and ._ files in $DIR" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
    find "$DIR" -name ".DS_Store" -delete -print | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE" 2>&1
    find "$DIR" -name "._*" -delete -print | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE" 2>&1
}

# Check if the destination is mounted
if [ "$OS" == "Darwin" ]; then
    # macOS: Check if the destination directory exists
    if [ -d "$DEST" ]; then
        echo "Destination directory exists: $DEST" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
    else
        echo "Error: Destination directory $DEST does not exist or is not mounted." | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
        exit 1
    fi
elif [ "$OS" == "Linux" ]; then
    # Linux: Check if the destination is mounted
    if grep -qs "$DEST" /proc/mounts; then
        echo "Destination directory exists and is mounted: $DEST" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
    else
        echo "Error: Destination directory $DEST does not exist or is not mounted." | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
        exit 1
    fi
else
    echo "Unsupported operating system: $OS" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
    exit 1
fi

# Cleanup source and destination directories
cleanup_files "$SOURCE"
cleanup_files "$DEST"

# Start rsync
rsync_output=$(rsync -av --itemize-changes --delete --no-perms --no-owner --no-group --chmod=a=rwx \
    --exclude="*Lucife*" \
    "$SOURCE/" "$DEST/" 2>&1)

# Count the number of files transferred, deleted, and errors
files_transferred=$(echo "$rsync_output" | grep -c '^>f')
files_deleted=$(echo "$rsync_output" | grep -c '^*deleting')
rsync_errors=$(echo "$rsync_output" | grep -i -c 'rsync error')

# Choose icons for each status
icon_success="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
icon_info="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
icon_error="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
icon_delete="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/TrashIcon.icns"
icon_sync="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns"

# Set your Telegram bot token and chat ID
TELEGRAM_BOT_TOKEN='7975126386:AAG-N0IAoNf0TsBEfd4cR2mpa9NtqqLIiUY'
TELEGRAM_CHAT_ID='7666167008'

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="Markdown"
}

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
echo "$rsync_output" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"

# Check rsync exit status
if [ $? -eq 0 ]; then
    terminal-notifier -title "Syncer" -message "Sync completed without errors." -sound default -appIcon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Checkmark.icns"
else
    terminal-notifier -title "Syncer" -message "Sync encountered errors. Check the log for details." -sound default -appIcon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
fi

# Log the end time
echo "Sync ended at $(date)" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"

# Add a separation footer for each run
{
    echo "========================================="
    echo "Script run ended at $(date)"
    echo "========================================="
} | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"

