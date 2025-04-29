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
echo "Starting rsync from $SOURCE to $DEST" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
rsync -av --itemize-changes --delete --no-perms --no-owner --no-group --chmod=a=rwx \
    --exclude="*Lucife*" \
    "$SOURCE/" "$DEST/" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE" 2>&1

# Check rsync exit status
if [ $? -eq 0 ]; then
    echo "Sync completed successfully at $(date)" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
else
    echo "Sync encountered errors at $(date)" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"
fi

# Log the end time
echo "Sync ended at $(date)" | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"

# Add a separation footer for each run
{
    echo "========================================="
    echo "Script run ended at $(date)"
    echo "========================================="
} | gawk '{print strftime("[%Y-%m-%d %H:%M:%S]"), $0}' >> "$LOGFILE"

