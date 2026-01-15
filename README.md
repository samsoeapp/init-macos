# macOS Setup Client

Modular macOS setup script with array-driven configuration. Installs Homebrew packages, 
App Store apps, applies system defaults, configures the Dock, and sets the default browser.

## One-Liner Installation

Run directly from the web without cloning:

```bash
# Default profile
curl -fsSL https://raw.githubusercontent.com/samsoeapp/init-macos/main/prep.sh | bash

# With a specific client profile
curl -fsSL https://raw.githubusercontent.com/samsoeapp/init-macos/main/prep.sh | bash -s -- --client acme

# Revert all defaults
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

The script executes 14 steps in sequence:

| Step | Description |
|------|-------------|
| 1 | Initialize sudo (request credentials, test, keep alive) |
| 2 | Install Xcode Command Line Tools |
| 3 | Install Homebrew |
| 4 | Install Homebrew formulae (CLI tools) |
| 5 | Install Homebrew casks (GUI apps) |
| 6 | Install App Store apps (if signed in) |
| 7 | Close System Settings |
| 8 | Initialize Safari (first launch) |
| 9 | Apply user-level macOS defaults |
| 10 | Apply admin-level macOS defaults |
| 11 | Configure Dock items |
| 12 | Set default browser (Google Chrome) |
| 13 | Restart affected apps (Finder, Dock) |
| 14 | Finalize and show summary |

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
macOS Setup Script
==================
Log file: /Users/user/Downloads/prep-20260115-143022.log

[ 1/14] Initializing sudo..................... OK
[ 2/14] Installing Xcode CLI Tools............ OK
[ 3/14] Installing Homebrew................... OK
[ 4/14] Installing Homebrew formulae.......... OK (2/2)
[ 5/14] Installing Homebrew casks............. OK (5/5)
[ 6/14] Installing App Store apps............. SKIPPED (not signed in)
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
