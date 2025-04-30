# SD Card Sync Service

This project automatically runs the `sdcard_sync.sh` script when a specific SD card is mounted. It supports both Linux (using systemd) and macOS (using launchd).

## Prerequisites

*   Bash shell
*   `rsync` command
*   (Optional) `curl` command (for Telegram notifications)
*   (Optional) `gawk` command (if you want timestamped logs - requires uncommenting the original `log` function in `sdcard_sync.sh`)

## Configuration

1.  **Edit `.env` file:**
    *   Set `SOURCE` to the directory you want to sync *from*.
    *   Set `DEST` to the directory on the SD card you want to sync *to*. This path is also used by the macOS `WatchPaths`.
    *   Set `MOUNT` to the exact mount point path of the SD card on Linux (e.g., `/media/paul/SD256`). This is used to generate the systemd mount unit dependency.
    *   (Optional) Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` if you want Telegram notifications.
2.  **Review `sdcard_sync.sh`:**
    *   Check the `rsync` options and `--exclude` patterns meet your needs.
    *   The script currently uses simplified `echo` for logging. If you want timestamps and have `gawk` installed, you can comment out the simple `log` function and uncomment the original `gawk`-based one.

## Installation & Usage

The `manage_sync_service.sh` script handles installation and uninstallation for the current operating system.

1.  Make sure you are in the project directory (`syncer2`).
2.  Ensure the script is executable: `chmod +x manage_sync_service.sh`
3.  **Install:** `./manage_sync_service.sh install`
    *   This will:
        *   Make `sdcard_sync.sh` executable.
        *   Read `.env` to get necessary paths.
        *   **On Linux:** Dynamically generate the `~/.config/systemd/user/sdcard-sync.service` file, linking it to the appropriate `.mount` unit derived from the `MOUNT` variable in `.env`, and enable the service.
        *   **On macOS:** Dynamically generate the `~/Library/LaunchAgents/com.user.sdcard.sync.plist` file, using the `DEST` variable from `.env` for `WatchPaths`, and load the agent.
4.  **Uninstall:** `./manage_sync_service.sh uninstall`
    *   This will disable and remove the generated systemd service or launchd plist file.
    *   It will also remove the log files (`sync.log`, `sdcard_sync_stdout.log`, `sdcard_sync_stderr.log`) from the project directory.

The sync script (`sdcard_sync.sh`) will now run automatically whenever the specified SD card is mounted (Linux) or the `DEST` path is mounted/modified (macOS). Logs are written to `sync.log` (and potentially stdout/stderr logs on macOS) in the project directory until uninstalled.

---

## Implementation Notes for AI (Linux/systemd)

If regenerating this setup using AI, follow these key steps for the Linux systemd implementation to avoid common pitfalls with auto-mounted devices:

1.  **Goal:** Trigger a script (`sdcard_sync.sh`) when a specific removable device is mounted at a known path (e.g., `/media/user/DEVICE_LABEL`).
2.  **Avoid `.path` Units:** While seemingly intuitive, `.path` units (monitoring `PathExists=` or `DirectoryNotEmpty=`) can be unreliable for auto-mounts, sometimes failing to trigger or triggering too rapidly (`start-limit-hit`).
3.  **Use `.mount` Unit Dependency:** The most robust method is to make the custom service depend directly on the systemd-generated `.mount` unit for the device.
    *   **Find Mount Unit Name:** After mounting the device, use `systemctl --user list-units '*.mount'` to find the exact unit name (e.g., `media-user-DEVICE_LABEL.mount`). Systemd creates this by replacing `/` with `-` in the mount path (after removing the leading `/`).
    *   **Configure Service (`.service` file):**
        *   Use `Requires=<mount_unit_name>` and `After=<mount_unit_name>` in the `[Unit]` section.
        *   Use `WantedBy=<mount_unit_name>` in the `[Install]` section. This is **crucial** for enabling the service to be triggered by the mount unit.
        *   Set `WorkingDirectory=` to the script's directory.
        *   Use `EnvironmentFile=` to load variables from `.env` instead of sourcing within the script.
        *   Use `ExecStart=` with either the absolute path to the script or `/bin/bash /path/to/script.sh`.
        *   Use `Type=oneshot`. `RemainAfterExit=yes` is generally *not* needed when triggered by a `.mount` unit.
    *   **Simplify Script:** Ensure the script uses commands compatible with the minimal systemd environment (e.g., prefer `echo` over `gawk` for basic logging if `gawk` isn't guaranteed).
4.  **Enable the Service:** After creating the `.service` file and reloading the daemon (`systemctl --user daemon-reload`), **enable** the service using `systemctl --user enable your-service-name.service`. This reads the `[Install]` section and creates the necessary symlink for the `.mount` unit dependency to work.

By following these steps, the service should reliably trigger exactly once when the specified device mount becomes active.