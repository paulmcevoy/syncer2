#!/bin/bash

# Set your source and destination
SOURCE="/Volumes/elements/other/"
DEST="/Volumes/SD256/MUSIC/other"
LOGFILE="/Users/paulmcevoy/syncer2/sync.log"

# Log the start time
echo "Sync started at $(date)" >> "$LOGFILE"

# Check if the SD card is mounted
if [ -d "$DEST" ]; then
    echo "Destination directory exists: $DEST" >> "$LOGFILE"
    echo "Starting rsync from $SOURCE to $DEST" >> "$LOGFILE"

    /usr/bin/rsync -av --itemize-changes --delete --no-perms --no-owner --no-group --chmod=a=rwx \
        --exclude="*Lucife*" \
        "$SOURCE/" "$DEST/" >> "$LOGFILE" 2>&1

    if [ $? -eq 0 ]; then
        echo "Sync completed successfully at $(date)" >> "$LOGFILE"
    else
        echo "Sync encountered errors at $(date)" >> "$LOGFILE"
    fi
else
    echo "Error: Destination directory $DEST does not exist or is not mounted." >> "$LOGFILE"
fi

# Log the end time
echo "Sync ended at $(date)" >> "$LOGFILE"

