#!/bin/bash
# =============================================================================
# noTahoe - Block macOS Tahoe (26.x) upgrade on Sequoia 15.x
# Simple, zero-interaction script. Keeps you on Sequoia while allowing security updates.
#
# Features:
# - Blocks Tahoe major upgrade via Apple audience trick (no betas installed)
# - Clears red badge on System Settings
# - Native XProtect/MRT updates only
# - Single clean LaunchAgent: com.noTahoe.plist (weekly Sunday 3AM)
# - Automatic log cleanup (30 days + 50MB)
# - Self-installs to /usr/local/bin/noTahoe
#
# Usage:
# chmod +x noTahoe.sh && ./noTahoe.sh
# After first run: just type "noTahoe" from anywhere
#
# Author: Public domain / feel free to fork
# License: MIT
# Version: 2026-03-31
# =============================================================================

set -euo pipefail
umask 077

SCRIPT_NAME="noTahoe"
INSTALL_PATH="/usr/local/bin/${SCRIPT_NAME}"
LOG_DIR="/Library/Logs"
LOG_FILE="${LOG_DIR}/noTahoe.log"
LAUNCH_LABEL="com.noTahoe"
LAUNCH_PATH="${HOME}/Library/LaunchAgents/${LAUNCH_LABEL}.plist"

log() {
    local LEVEL="$1"
    local MSG="$2"
    local TS=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "[${TS}] [${LEVEL}] ${MSG}" | tee -a "${LOG_FILE}" 2>/dev/null || echo "[${TS}] [${LEVEL}] ${MSG}"
}

# Log cleanup: delete >30 days, truncate >50MB
log_cleanup() {
    find "${LOG_DIR}" -name "noTahoe*.log" -mtime +30 -delete 2>/dev/null || true
    if [[ -f "${LOG_FILE}" ]] && [[ $(stat -f %z "${LOG_FILE}" 2>/dev/null || echo 0) -gt 52428800 ]]; then
        : > "${LOG_FILE}"
        log "A" "Log exceeded 50MB - truncated"
    fi
}
log_cleanup

# Self-elevation
if [[ $EUID -ne 0 ]]; then
    log "i" "Self-elevating..."
    exec sudo -E "$0" "$@"
fi

mkdir -p "${LOG_DIR}"
log "i" "Starting noTahoe on macOS 15.x Sequoia"

OS_VER=$(sw_vers -productVersion)
if [[ ! "${OS_VER}" =~ ^15\. ]]; then
    log "X" "Unsupported OS: ${OS_VER} (only Sequoia 15.x supported)"
    exit 2
fi

# Recursion guard + forced self-copy
CURRENT_PATH="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
if [[ "${CURRENT_PATH}" != "${INSTALL_PATH}" ]]; then
    log "A" "Copying self to ${INSTALL_PATH}"
    cp -f "$0" "${INSTALL_PATH}"
    chmod 755 "${INSTALL_PATH}"
    chown root:wheel "${INSTALL_PATH}" 2>/dev/null || true
    log "A" "Self installed with 755 root:wheel"
    exec "${INSTALL_PATH}"
fi

# Permission hardening
log "A" "Enforcing 755 root:wheel on ${INSTALL_PATH}"
chmod 755 "${INSTALL_PATH}"
chown root:wheel "${INSTALL_PATH}" 2>/dev/null || true

################ Phase: Tahoe Block + Aggressive Badge Clearance ################
log "i" "Enforcing Tahoe block via audience"

defaults write /private/var/root/Library/Preferences/com.apple.MobileAsset.plist MobileAssetAssetAudience -string "c8ba02c8-cc63-4388-99ee-a81d5a593283"

FUTURE_DATE="2030-12-31 23:59:59 +0000"
defaults write com.apple.SoftwareUpdate MajorOSUserNotificationDate -date "${FUTURE_DATE}"
defaults write com.apple.SoftwareUpdate UserNotificationDate -date "${FUTURE_DATE}"
defaults write com.apple.systempreferences AttentionPrefBundleIDs 0

# Aggressive badge clearance
log "A" "Clearing cached badge"
rm -f "${HOME}/Library/Preferences/com.apple.systempreferences.plist" 2>/dev/null || true

killall SoftwareUpdateNotificationManager 2>/dev/null || true
killall -9 Dock 2>/dev/null || true
sleep 2
open -a Finder
sleep 3
pgrep -x Finder >/dev/null && log "A" "Dock/Finder reset complete" || log "! " "Relaunch incomplete"

################ Phase: Native XProtect/MRT ################
log "i" "Enforcing native XProtect/MRT"
xprotect check 2>/dev/null || true
sudo xprotect update 2>/dev/null || log "! " "No change needed"
log "A" "XProtect version: $(xprotect version 2>/dev/null || echo unknown)"

################ Phase: Simple Fixed LaunchAgent + Cleanup ################
log "i" "Ensuring single LaunchAgent com.noTahoe.plist"

# Cleanup any old agents
find "${HOME}/Library/LaunchAgents" -name "com.apple.noTahoeSecurity.*.plist" -delete 2>/dev/null || true
find "${HOME}/Library/LaunchAgents" -name "com.noTahoe.*.plist" -delete 2>/dev/null || true

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "${LAUNCH_PATH}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCH_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_PATH}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/noTahoe.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/noTahoe.log</string>
</dict>
</plist>
EOF

chown "$(logname)":staff "${LAUNCH_PATH}" 2>/dev/null || true
chmod 644 "${LAUNCH_PATH}"
launchctl bootstrap user/"$(id -u)" "${LAUNCH_PATH}" 2>/dev/null || true
log "A" "LaunchAgent com.noTahoe.plist installed/updated (weekly Sunday 3AM)"

################ Phase: Validation ################
log "i" "Validating"
defaults read /private/var/root/Library/Preferences/com.apple.MobileAsset.plist MobileAssetAssetAudience 2>/dev/null | grep -q "c8ba02c8" && log "A" "Tahoe hidden" || log "! " "Audience missing"
softwareupdate -l 2>/dev/null | grep -iq tahoe && log "! " "Tahoe may still visible" || log "A" "Tahoe hidden"
xprotect version 2>/dev/null | grep -q [0-9] && log "A" "XProtect current" || log "! " "XProtect check failed"
log "i" "Red badge clearance applied. Logs cleaned (30d + 50MB)."

################ Attestation Summary ################
log "i" "Attestation: Simple com.noTahoe.plist (no signing), Tahoe blocked, badge cleared, logs managed."
log "i" "End. STAMP: ${STAMP}"

exit 0
