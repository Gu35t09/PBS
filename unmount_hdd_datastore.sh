#!/usr/bin/env bash
#
# Unmount a single Proxmox Backup Server (PBS) datastore by checking
# whether the block device identified by its UUID is attached.
#
# Logging:
#   • Human‑readable output on the console (STDOUT)
#   • Append to /var/log/pbs-datastore-unmount.log
#
# -------------------------------------------------------------
#
# Prerequisites:
#   • You know the UUID of the block device that backs the datastore.
#   • Run as root (or via sudo) because PBS commands need privilege.
# -------------------------------------------------------------

set -euo pipefail   # Safer scripting

# -------------------- Configuration --------------------
# Add or edit entries here to match your environment.
declare -A DS_UUID=(
    ["ext-hdd"]="85e7b627-e080-40ad-8a8f-c0d9073b0941"
)

# Log file location – make sure the directory exists and is writable by root.
LOG_FILE="/var/log/pbs-datastore-unmount.log"
# Syslog facility/tag (feel free to change “pbs-unmount” to anything you like).
SYSLOG_TAG="pbs-datastore-unmount"
# -----------------------------------------------------

# ---------- Helper functions ----------
_log_to_file_and_syslog() {
    local level="$1"   # info, warning, error …
    local msg="$2"

    # Build a unified line with timestamp and level.
    local line="[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $msg"

    # Print to console (STDOUT)
    echo "$line"

    # Append to the dedicated log file (create it if missing)
    echo "$line" >>"$LOG_FILE"
}

log_info()    { _log_to_file_and_syslog "info"    "$*"; }
log_warn()    { _log_to_file_and_syslog "warning" "$*"; }
log_error()   { _log_to_file_and_syslog "error"   "$*"; }

# Write a visual separator + “New session” header at the start of every run.
write_session_header() {
    local sep="------------------------------------------------------------"
    # Separator line
    echo "$sep" | tee -a "$LOG_FILE"
    # New session line
    log_info "New logging session"
    # Another separator (optional, makes the log block easy to scan)
    echo "$sep" | tee -a "$LOG_FILE"
}


# Return 0 if the given UUID exists under /dev/disk/by-uuid, else 1.
uuid_present() {
    local uuid="$1"
    [[ -e "/dev/disk/by-uuid/${uuid}" ]]
}

# Unmount a datastore via the PBS CLI, handling errors gracefully.
unmount_ds() {
    local ds="$1"
    log_info "Attempting to unmount datastore '${ds}' …"
    if proxmox-backup-manager datastore unmount "${ds}"; then
        log_info "Datastore '${ds}' successfully unmounted."
    else
        log_error "Failed to unmount '${ds}'. Check PBS logs or try manually."
    fi
}

# ---------- Main logic ----------
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <datastore>"
    exit 1
fi

# Write the session header before doing anything else.
write_session_header

DS="$1"

# Verify we have a UUID entry for the supplied name.
if [[ -z "${DS_UUID[$DS]:-}" ]]; then
    log_error "No UUID configured for datastore '${DS}'. Edit the DS_UUID array."
    exit 1
fi

log_info "Checking presence of UUID for datastore '${DS}' …"

if uuid_present "${DS_UUID[$DS]}"; then
    log_info "UUID for '${DS}' is present (disk attached)."
    unmount_ds "${DS}"
else
    log_info "UUID for '${DS}' NOT found (disk absent). Nothing to unmount."
fi

exit 0
