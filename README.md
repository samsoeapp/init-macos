# macOS Setup Client

Modular macOS setup script with array-driven configuration. Installs Homebrew packages, 
App Store apps, applies system defaults, configures the Dock, and sets the default browser.

## One-Liner Installation

Run directly from the web without cloning:

```bash
# Default profile
curl -fsSL https://craftu.re/macos | bash
curl -fsSL https://raw.githubusercontent.com/samsoeapp/init-macos/main/prep.sh | bash

# With a specific client profile
curl -fsSL https://craftu.re/macos | bash -s -- --client acme
curl -fsSL https://raw.githubusercontent.com/samsoeapp/init-macos/main/prep.sh | bash -s -- --client acme

# Revert all defaults
curl -fsSL https://craftu.re/macos | bash -s -- --revert
curl -fsSL https://raw.githubusercontent.com/samsoeapp/init-macos/main/prep.sh | bash -s -- --revert
```

## Quick Start

```bash
# Run with default profile
./prep.sh

# Run with a specific client profile
./prep.sh --client acme

# Revert all defaults to system defaults
./prep.sh --revert
```

## What It Does

The script executes 17 steps in sequence:

| Step | Description |
|------|-------------|
| 1 | Initialize sudo (request credentials, test, keep alive) |
| 2 | Apply admin-level macOS defaults (immediately after sudo) |
| 3 | Unhide /Volumes (immediately after sudo) |
| 4 | Set computer name (ComputerName, HostName, LocalHostName, NetBIOSName) |
| 5 | Install Xcode Command Line Tools |
| 6 | Install Homebrew |
| 7 | Install Homebrew formulae (CLI tools) |
| 8 | Install Homebrew casks (GUI apps) |
| 9 | Install App Store apps (if signed in) |
| 10 | Close System Settings |
| 11 | Initialize Safari (open/close to create writable preferences) |
| 12 | Apply Safari defaults (sandboxed on macOS 14+) |
| 13 | Apply user-level macOS defaults |
| 14 | Configure Dock items |
| 15 | Set default browser (Google Chrome) |
| 16 | Restart affected apps (Finder, Dock) |
| 17 | Finalize and show summary |

## Configuration

All configuration is defined in arrays at the top of `prep.sh`:

### Dock Items
```bash
DOCK_ITEMS=(
  "/Applications/Google Chrome.app"
  "/Applications/Slack.app"
  "SPACER"  # Adds a spacer tile
  "/System/Applications/System Settings.app"
)
```

### Homebrew Packages
```bash
BREW_FORMULAE=(
  "mas"
  "dockutil"
)

BREW_CASKS=(
  "google-chrome"
  "slack"
  "1password"
  "arc"
)
```

### App Store Apps
```bash
# Format: "app_id|App Name"
MAS_APPS=(
  "409201541|Pages"
  "409203825|Numbers"
)
```

### macOS Defaults
```bash
# Format: "domain|key|value|type"
# Types: bool, string, int, float
DEFAULTS_USER=(
  "com.apple.finder|ShowPathbar|true|bool"
  "NSGlobalDomain|AppleShowAllExtensions|true|bool"
  "-currentHost|com.apple.Spotlight|MenuItemHidden|1|int"
)

# Admin defaults (requires sudo)
DEFAULTS_ADMIN=(
  "/Library/Preferences/com.apple.loginwindow|AdminHostInfo|HostName|string"
)
```

### Default Browser
```bash
DEFAULT_BROWSER="Google Chrome"
```

### Computer Name
```bash
# Set to empty string to skip, or use "__SERIAL__" for serial number
COMPUTER_NAME=""
COMPUTER_NAME="MacBook-Pro"
COMPUTER_NAME="__SERIAL__"
```

## Client Profiles

Edit the `apply_client_profile()` function to add custom profiles:

```bash
apply_client_profile() {
  case "$CLIENT_PROFILE" in
    default)
      BREW_CASKS=("google-chrome" "slack")
      ;;
    acme)
      BREW_CASKS=("firefox" "zoom" "microsoft-teams")
      DOCK_ITEMS+=("/Applications/Zoom.app")
      ;;
  esac
}
```

Run with: `./prep.sh --client acme`

## Output

### Console Output
Clean step-by-step progress with status indicators:

```
macOS Setup Script V1.17
========================
Log file: /Users/user/Downloads/prep-20260115-143022.log

[ 1/17] Initializing sudo..................... OK
[ 2/17] Installing Xcode CLI Tools............ OK
[ 3/17] Installing Homebrew................... OK
[ 4/17] Installing Homebrew formulae.......... OK (2/2)
[ 5/17] Installing Homebrew casks............. OK (6/6)
[ 6/17] Installing App Store apps............. SKIPPED (not signed in)
...

==================
Summary
==================
All tasks completed successfully.
Log file: /Users/user/Downloads/prep-20260115-143022.log
```

### Log File
Full verbose output is written to `~/Downloads/prep-YYYYMMDD-HHMMSS.log`

## Command Line Options

| Option | Description |
|--------|-------------|
| `--client NAME` | Apply a specific client profile |
| `--revert` | Revert all defaults to system defaults |
| `--accept-xcode-license` | Automatically accept Xcode license |
| `-v, --version` | Show version number |
| `-h, --help` | Show help message |

## Requirements

- macOS (tested on Sonoma and later)
- Internet connection
- Admin account (for Homebrew and some defaults)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied | Run `chmod +x prep.sh` |
| Homebrew fails | Check internet or install manually from https://brew.sh |
| App Store apps skip | Sign into App Store first: `mas signin` or open App Store app |
| Dock not updating | Ensure `dockutil` is in BREW_FORMULAE |
| Check full log | `~/Downloads/prep-YYYYMMDD-HHMMSS.log` |

## Files

| File | Description |
|------|-------------|
| `prep.sh` | Main script with all configuration |
| `~/Downloads/prep-*.log` | Execution logs |
