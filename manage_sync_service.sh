#!/bin/bash

# Get the absolute path of the directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_FILE="$SCRIPT_DIR/.env"

# --- Configuration ---
LINUX_SYSTEMD_DIR="$HOME/.config/systemd/user"
LINUX_SERVICE_FILE="sdcard-sync.service" # Name of the service file to generate/remove

MACOS_LAUNCHD_DIR="$HOME/Library/LaunchAgents"
MACOS_PLIST_FILE="com.user.sdcard.sync.plist" # Name of the plist file to generate/remove

SYNC_SCRIPT_NAME="sdcard_sync.sh" # Just the script filename
# --- End Configuration ---

# --- Helper Functions ---
print_usage() {
  echo "Usage: $0 [install|uninstall]"
  exit 1
}

print_info() {
  echo "[INFO] $1"
}

print_error() {
  echo "[ERROR] $1" >&2
  exit 1
}

source_env() {
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found at $ENV_FILE"
    fi
    # Source the .env file, handling potential errors or complexities if needed
    set -a # Automatically export all variables
    source "$ENV_FILE" || print_error "Failed to source $ENV_FILE"
    set +a # Stop automatically exporting
    print_info "Sourced environment variables from $ENV_FILE"
}

# --- Linux Functions (systemd) ---
install_linux() {
  print_info "Installing for Linux (systemd)..."
  source_env

  # Check required variables
  if [ -z "$MOUNT" ]; then
      print_error "MOUNT variable not set in $ENV_FILE"
  fi
  local sync_script_path="$SCRIPT_DIR/$SYNC_SCRIPT_NAME"
  if [ ! -f "$sync_script_path" ]; then
      print_error "Sync script not found at $sync_script_path"
  fi

  # Make sync script executable
  chmod +x "$sync_script_path" || print_error "Failed to make sync script executable."

  # Generate the systemd mount unit name from the MOUNT path
  # systemd-escape might not be available, use basic conversion
  local mount_unit_name=$(echo "$MOUNT" | sed -e 's/^\///' -e 's/\//-/g').mount
  print_info "Using mount unit name: $mount_unit_name"

  local target_service_path="$LINUX_SYSTEMD_DIR/$LINUX_SERVICE_FILE"
  mkdir -p "$LINUX_SYSTEMD_DIR" || print_error "Failed to create systemd user directory."

  # Generate the service file content using a heredoc
  cat << EOF > "$target_service_path" || print_error "Failed to write systemd service file."
[Unit]
Description=Run SD Card Sync Script on Mount ($MOUNT)
Requires=$mount_unit_name
After=$mount_unit_name

[Service]
Type=oneshot
WorkingDirectory=$SCRIPT_DIR
EnvironmentFile=$ENV_FILE
ExecStart=/bin/bash $sync_script_path

[Install]
WantedBy=$mount_unit_name
EOF

  print_info "Generated service file at $target_service_path"

  # Reload systemd, enable the service unit
  systemctl --user daemon-reload || print_error "Failed to reload systemd user daemon."
  systemctl --user enable "$LINUX_SERVICE_FILE" || print_error "Failed to enable systemd service unit."
  print_info "Linux systemd service installed and enabled (will trigger on mount)."
}

uninstall_linux() {
  print_info "Uninstalling for Linux (systemd)..."
  local target_service_path="$LINUX_SYSTEMD_DIR/$LINUX_SERVICE_FILE"
  systemctl --user disable "$LINUX_SERVICE_FILE" 2>/dev/null # Ignore errors if not found
  rm -f "$target_service_path" || print_error "Failed to remove systemd service file."
  systemctl --user daemon-reload || print_error "Failed to reload systemd user daemon."
  # Remove log file
  rm -f "$SCRIPT_DIR/sync.log"
  print_info "Removed sync.log"
  print_info "Linux systemd service uninstalled."
}

# --- macOS Functions (launchd) ---
install_macos() {
  print_info "Installing for macOS (launchd)..."
  source_env

  # Check required variables
  if [ -z "$DEST" ]; then # Using DEST for WatchPaths as per original plist logic
      print_error "DEST variable not set in $ENV_FILE (used for WatchPaths)"
  fi
   local sync_script_path="$SCRIPT_DIR/$SYNC_SCRIPT_NAME"
  if [ ! -f "$sync_script_path" ]; then
      print_error "Sync script not found at $sync_script_path"
  fi

  # Make sync script executable
  chmod +x "$sync_script_path" || print_error "Failed to make sync script executable."

  local target_plist_path="$MACOS_LAUNCHD_DIR/$MACOS_PLIST_FILE"
  mkdir -p "$MACOS_LAUNCHD_DIR" || print_error "Failed to create LaunchAgents directory."

  # Generate the plist file content using a heredoc
  # NOTE: Assumes DEST variable in .env is the correct path to WATCH on macOS
  #       (e.g., /Volumes/SD256/MUSIC/other)
  cat << EOF > "$target_plist_path" || print_error "Failed to write launchd plist file."
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$(basename "$MACOS_PLIST_FILE" .plist)</string>

    <key>ProgramArguments</key>
    <array>
        <string>$sync_script_path</string>
    </array>

    <key>WatchPaths</key>
    <array>
        <string>$DEST</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StartOnMount</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/sdcard_sync_stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/sdcard_sync_stderr.log</string>
</dict>
</plist>
EOF

  print_info "Generated plist file at $target_plist_path"

  # Load the launch agent
  launchctl load "$target_plist_path" || print_error "Failed to load launch agent. It might already be loaded."
  print_info "macOS launch agent installed and loaded."
}

uninstall_macos() {
  print_info "Uninstalling for macOS (launchd)..."
  local target_plist_path="$MACOS_LAUNCHD_DIR/$MACOS_PLIST_FILE"
  launchctl unload "$target_plist_path" 2>/dev/null # Ignore errors if not found
  rm -f "$target_plist_path" || print_error "Failed to remove plist file."
  # Remove log files
  rm -f "$SCRIPT_DIR/sync.log" "$SCRIPT_DIR/sdcard_sync_stdout.log" "$SCRIPT_DIR/sdcard_sync_stderr.log"
  print_info "Removed log files (sync.log, sdcard_sync_stdout.log, sdcard_sync_stderr.log)"
  print_info "macOS launch agent unloaded and uninstalled."
}

# --- Main Script Logic ---
if [ $# -ne 1 ]; then
  print_usage
fi

ACTION=$1

OS_TYPE=$(uname)

case "$OS_TYPE" in
  Linux)
    if [ "$ACTION" == "install" ]; then
      install_linux
    elif [ "$ACTION" == "uninstall" ]; then
      uninstall_linux
    else
      print_error "Invalid action: $ACTION"
      print_usage
    fi
    ;;
  Darwin) # macOS returns Darwin
    if [ "$ACTION" == "install" ]; then
      install_macos
    elif [ "$ACTION" == "uninstall" ]; then
      uninstall_macos
    else
      print_error "Invalid action: $ACTION"
      print_usage
    fi
    ;;
  *)
    print_error "Unsupported operating system: $OS_TYPE"
    ;;
esac

exit 0