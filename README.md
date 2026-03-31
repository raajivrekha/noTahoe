# noTahoe

**Block macOS Tahoe (26.x) upgrade while staying on Sequoia 15.x**

Simple, zero-interaction script. Prevents the Tahoe upgrade prompt and red badge while still allowing native security updates (XProtect/MRT).

## Features
- Hides Tahoe completely (no more red badge or upgrade prompt)
- Uses Apple's audience trick (no beta enrollment, no beta software ever installed)
- Keeps native XProtect and MRT updates via `xprotect`
- Single clean LaunchAgent (`com.noTahoe.plist`)
- Automatic log cleanup (older than 30 days or larger than 50 MB)
- Self-installs to `/usr/local/bin/noTahoe`

## Requirements and Caveats
- Requires elevation (Administrator Privileges)
- Can be run as a regular user however it does attempt to self elevate and does so cleanly if your user is given NOPASSWD in sudoers. Run this to find out:
```bash
alias sudocheck='{ echo -e "USER\tNOPASSWD"; sudo -n ls /dev/null >/dev/null 2>&1 && s="ENABLED" || s="DISABLED"; printf "%-15s %s\n" "$(whoami)" "$s"; } | column -t'
sudocheck
```

- Upon self elevation without NOPASSWD set, you may be prompted for your credentials to elevate

## Install
### One-line Install

```bash
curl -fsSL https://raw.githubusercontent.com/raajivrekha/noTahoe/main/noTahoe.sh | sudo bash
```

### Manual Install
```bash
curl -L -O https://raw.githubusercontent.com/raajivrekha/noTahoe/main/noTahoe.sh
chmod +x noTahoe.sh
./noTahoe.sh
```

## Uninstall (Full Removal)
### 1. Remove the script
```bash
sudo rm -f /usr/local/bin/noTahoe
```

### 2. Remove the LaunchAgent
```bash
rm -f ~/Library/LaunchAgents/com.noTahoe.plist
```

### 3. Reset Software Update to default
```bash
defaults delete /private/var/root/Library/Preferences/com.apple.MobileAsset.plist MobileAssetAssetAudience 2>/dev/null || true
defaults delete com.apple.SoftwareUpdate MajorOSUserNotificationDate 2>/dev/null || true
defaults delete com.apple.SoftwareUpdate UserNotificationDate 2>/dev/null || true
defaults write com.apple.systempreferences AttentionPrefBundleIDs 1
```

### 4. Reset Software Update catalog
```bash
softwareupdate --reset 2>/dev/null || true
```
### 5. Final cleanup
```bash
killall Dock 2>/dev/null || true
```
