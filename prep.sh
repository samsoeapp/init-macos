#!/usr/bin/env bash
# =============================================================================
# macOS Setup Script
# =============================================================================
# HOW TO EDIT THIS FILE:
# - Dock items: Add/remove app paths in DOCK_ITEMS array
# - macOS defaults: Add entries to DEFAULTS_USER or DEFAULTS_ADMIN arrays
#   Format: "domain|key|value|type" where type is: bool, string, int, float
# - Homebrew packages: Add/remove entries in BREW_FORMULAE/BREW_CASKS arrays
# - App Store apps: Add/remove entries in MAS_APPS array (format: "app_id|App Name")
# - Client profiles: Edit apply_client_profile() and run with --client NAME
# After editing, run: ./prep.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Version (update this with each commit: V1.XX where XX = commit count)
# -----------------------------------------------------------------------------
VERSION="V1.12"

# -----------------------------------------------------------------------------
# Shell Options
# -----------------------------------------------------------------------------
set -u -o pipefail

# -----------------------------------------------------------------------------
# Configuration Arrays
# -----------------------------------------------------------------------------

# Default browser (set to empty string to skip)
DEFAULT_BROWSER="Google Chrome"

# Dock items - paths to applications (use "SPACER" for a spacer tile)
DOCK_ITEMS=(
  "/Applications/Google Chrome.app"
  "/Applications/Google Drive.app"
  "/Applications/1Password.app"
  "/Applications/WhatsApp.app"
  "/Applications/Slack.app"
  "/Applications/Microsoft Word.app"
  "/Applications/Microsoft Excel.app"
  "/System/Applications/Notes.app"
  "/System/Applications/Calendar.app"
  "/Applications/Safari.app"
  "/System/Applications/System Settings.app"
)

# Homebrew formulae (command-line tools)
BREW_FORMULAE=()

# Homebrew casks (GUI applications)
BREW_CASKS=()

# Mac App Store apps - format: "app_id|App Name"
MAS_APPS=(
  "409201541|Pages"
  "409203825|Numbers"
  "409183694|Keynote"
)

# macOS defaults (user-level) - format: "domain|key|value|type"
# Types: bool, string, int, float
# Use "-g" or "NSGlobalDomain" for global domain
# Use "-currentHost" prefix for currentHost writes (e.g., "-currentHost|com.apple.Spotlight|MenuItemHidden|1|int")
DEFAULTS_USER=(
  # General UI/UX
  "NSGlobalDomain|NSNavPanelExpandedStateForSaveMode|true|bool"
  "NSGlobalDomain|NSNavPanelExpandedStateForSaveMode2|true|bool"
  "NSGlobalDomain|PMPrintingExpandedStateForPrint|true|bool"
  "NSGlobalDomain|PMPrintingExpandedStateForPrint2|true|bool"
  "com.apple.Siri|SiriPrefStashedStatusMenuVisible|false|bool"
  "com.apple.Siri|VoiceTriggerUserEnabled|false|bool"
  "-g|AppleWindowTabbingMode|always|string"
  "com.apple.controlcenter|NSStatusItem Visible Bluetooth|true|bool"
  "com.apple.controlcenter|NSStatusItem Visible Sound|true|bool"
  "-currentHost|com.apple.Spotlight|MenuItemHidden|1|int"
  # Finder
  "com.apple.finder|ShowPathbar|true|bool"
  "com.apple.finder|FXPreferredViewStyle|Nlsv|string"
  "com.apple.finder|ShowStatusBar|true|bool"
  "com.apple.finder|AppleShowAllFiles|true|bool"
  "NSGlobalDomain|AppleShowAllExtensions|true|bool"
  # Text Input
  "NSGlobalDomain|NSAutomaticCapitalizationEnabled|false|bool"
  "NSGlobalDomain|NSAutomaticSpellingCorrectionEnabled|false|bool"
  # Bluetooth
  "com.apple.BluetoothAudioAgent|Apple Bitpool Min (editable)|40|int"
  # Network
  "com.apple.NetworkBrowser|BrowseAllInterfaces|true|bool"
  # Screenshots
  "com.apple.screencapture|location|__HOME__/Downloads|string"
  "com.apple.screencapture|type|png|string"
)

# Safari defaults - handled separately due to sandboxed container on macOS 14+
# Format: "key|value|type"
SAFARI_DEFAULTS=(
  "IncludeDevelopMenu|true|bool"
  "WebKitDeveloperExtrasEnabledPreferenceKey|true|bool"
  "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled|true|bool"
  "AutoFillFromAddressBook|false|bool"
  "AutoFillPasswords|false|bool"
  "AutoFillCreditCardData|false|bool"
  "AutoFillMiscellaneousForms|false|bool"
  "SendDoNotTrackHTTPHeader|true|bool"
)

# macOS defaults (admin-level, requires sudo) - format: "domain|key|value|type"
DEFAULTS_ADMIN=(
  # Uncomment to enable admin defaults
  # "/Library/Preferences/com.apple.loginwindow|AdminHostInfo|HostName|string"
)

# -----------------------------------------------------------------------------
# Runtime Variables (do not edit)
# -----------------------------------------------------------------------------
LOG_FILE="${HOME}/Downloads/prep-$(date '+%Y%m%d-%H%M%S').log"
FAILURES=()
WARNINGS=()
SKIPPED=()
STEP_NUM=0
TOTAL_STEPS=15
REVERT_DEFAULTS=false
CLIENT_PROFILE=""
SUDO_KEEPALIVE_PID=""
SUDO_INITIALIZED=false
ACCEPT_XCODE_LICENSE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"

# Step result tracking (not used, kept for potential future use)

# -----------------------------------------------------------------------------
# Logging and Output Functions
# -----------------------------------------------------------------------------

log_to_file() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

log_verbose() {
  # Only logs to file, not to console
  log_to_file "$*"
}

log_success() {
  log_to_file "OK: $*"
}

log_warn() {
  log_to_file "WARN: $*"
  WARNINGS+=("$*")
}

log_error() {
  log_to_file "ERROR: $*"
  FAILURES+=("$*")
}

log_skip() {
  log_to_file "SKIP: $*"
  SKIPPED+=("$*")
}

# Print step progress with dynamic status
print_step() {
  local step_num="$1"
  local total="$2"
  local description="$3"
  local status="${4:-}"
  local detail="${5:-}"
  
  # Pad step number for alignment
  local padded_step
  padded_step=$(printf "%2d" "$step_num")
  
  # Create dots for alignment (50 chars total for description + dots)
  local desc_len=${#description}
  local dots_needed=$((45 - desc_len))
  local dots=""
  for ((i=0; i<dots_needed; i++)); do
    dots="${dots}."
  done
  
  if [[ -n "$status" ]]; then
    if [[ -n "$detail" ]]; then
      printf "\r[%s/%d] %s%s %s (%s)\n" "$padded_step" "$total" "$description" "$dots" "$status" "$detail"
    else
      printf "\r[%s/%d] %s%s %s\n" "$padded_step" "$total" "$description" "$dots" "$status"
    fi
  else
    printf "[%s/%d] %s%s " "$padded_step" "$total" "$description" "$dots"
  fi
}

step_start() {
  STEP_NUM=$((STEP_NUM + 1))
  local description="$1"
  print_step "$STEP_NUM" "$TOTAL_STEPS" "$description"
  log_to_file "=== STEP $STEP_NUM/$TOTAL_STEPS: $description ==="
}

step_ok() {
  local detail="${1:-}"
  print_step "$STEP_NUM" "$TOTAL_STEPS" "${CURRENT_STEP_DESC:-Step}" "OK" "$detail"
}

step_fail() {
  local detail="${1:-}"
  print_step "$STEP_NUM" "$TOTAL_STEPS" "${CURRENT_STEP_DESC:-Step}" "FAILED" "$detail"
}

step_skip() {
  local detail="${1:-}"
  print_step "$STEP_NUM" "$TOTAL_STEPS" "${CURRENT_STEP_DESC:-Step}" "SKIPPED" "$detail"
}

# Track current step description for status updates
CURRENT_STEP_DESC=""
begin_step() {
  STEP_NUM=$((STEP_NUM + 1))
  CURRENT_STEP_DESC="$1"
  print_step "$STEP_NUM" "$TOTAL_STEPS" "$1"
  log_to_file "=== STEP $STEP_NUM/$TOTAL_STEPS: $1 ==="
}

# -----------------------------------------------------------------------------
# Command Execution Helpers
# -----------------------------------------------------------------------------

# Run command, log output, track success/failure
# Returns: 0 on success, 1 on failure
run_cmd() {
  local desc="$1"
  shift
  log_verbose "Running: $*"
  if "$@" >> "$LOG_FILE" 2>&1; then
    log_success "$desc"
    return 0
  else
    log_error "$desc"
    return 1
  fi
}

# Run command with sudo
run_cmd_admin() {
  local desc="$1"
  shift
  ensure_sudo
  log_verbose "Running (admin): sudo $*"
  if sudo -n "$@" >> "$LOG_FILE" 2>&1; then
    log_success "$desc"
    return 0
  else
    log_error "$desc (admin session may have expired)"
    return 1
  fi
}

# Run command, warn on failure but don't track as error
run_optional() {
  local desc="$1"
  shift
  log_verbose "Running (optional): $*"
  if "$@" >> "$LOG_FILE" 2>&1; then
    log_success "$desc"
    return 0
  else
    log_warn "$desc"
    return 1
  fi
}

# Run optional command with sudo
run_optional_admin() {
  local desc="$1"
  shift
  ensure_sudo
  log_verbose "Running (optional admin): sudo $*"
  if sudo -n "$@" >> "$LOG_FILE" 2>&1; then
    log_success "$desc"
    return 0
  else
    log_warn "$desc (admin)"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# macOS Version Detection
# -----------------------------------------------------------------------------

# Get macOS major version number (e.g., 14 for Sonoma, 15 for Sequoia)
get_macos_major_version() {
  sw_vers -productVersion | cut -d '.' -f 1
}

# Check if macOS version is at least the specified version
macos_version_at_least() {
  local required_version=$1
  local current_version
  current_version=$(get_macos_major_version)
  [[ "$current_version" -ge "$required_version" ]]
}

# -----------------------------------------------------------------------------
# Sudo Management
# -----------------------------------------------------------------------------

# Temporary file for sudo password (securely stored)
SUDO_PASSWORD_FILE=""

init_sudo() {
  if [[ "$SUDO_INITIALIZED" == "true" ]]; then
    return 0
  fi
  
  # Check if sudo command exists
  if ! command -v sudo >/dev/null 2>&1; then
    log_warn "sudo not available on this system"
    return 1
  fi
  
  log_to_file "Requesting sudo credentials..."
  printf "\nAdmin access is required. Please authenticate.\n"
  
  # Read password securely from /dev/tty (works even when stdin is piped)
  local sudo_password
  printf "Password: "
  read -r -s sudo_password < /dev/tty
  printf "\n"
  
  # Test if password is correct
  if ! printf '%s\n' "$sudo_password" | sudo -S -v 2>/dev/null; then
    log_error "Failed to obtain sudo credentials (incorrect password)"
    return 1
  fi
  
  log_to_file "Sudo credentials obtained successfully"
  
  # Store password securely in a temporary file for later use
  # This is needed because Homebrew clears sudo timestamp during cask installations
  SUDO_PASSWORD_FILE=$(mktemp)
  chmod 600 "$SUDO_PASSWORD_FILE"
  printf '%s' "$sudo_password" > "$SUDO_PASSWORD_FILE"
  
  # Export the path so subshells can access it
  export SUDO_PASSWORD_FILE
  
  # Clear password from memory
  sudo_password=""
  
  # Keep sudo timestamp alive as a primary mechanism
  (
    while true; do
      sleep 5
      # Check if parent script is still running
      kill -0 "$$" 2>/dev/null || exit 0
      # Refresh sudo timestamp using stored password
      if [[ -f "$SUDO_PASSWORD_FILE" ]]; then
        cat "$SUDO_PASSWORD_FILE" | sudo -S -v >/dev/null 2>&1 || true
      fi
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
  
  SUDO_INITIALIZED=true
  log_success "Sudo initialized and keepalive started (PID: $SUDO_KEEPALIVE_PID)"
  return 0
}

# Refresh sudo using stored password (call before operations that need sudo)
refresh_sudo() {
  if [[ -n "${SUDO_PASSWORD_FILE:-}" && -f "$SUDO_PASSWORD_FILE" ]]; then
    cat "$SUDO_PASSWORD_FILE" | sudo -S -v >/dev/null 2>&1 || true
  else
    sudo -v >/dev/null 2>&1 || true
  fi
}

ensure_sudo() {
  if [[ "$SUDO_INITIALIZED" != "true" ]]; then
    init_sudo
  fi
}

cleanup_sudo() {
  # Kill the keepalive background process
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    log_to_file "Sudo keepalive process stopped"
  fi
  # Securely remove the password file
  if [[ -n "${SUDO_PASSWORD_FILE:-}" && -f "$SUDO_PASSWORD_FILE" ]]; then
    rm -f "$SUDO_PASSWORD_FILE" 2>/dev/null || true
    log_to_file "Sudo password file removed"
  fi
  # Invalidate sudo timestamp
  if command -v sudo >/dev/null 2>&1; then
    sudo -k >/dev/null 2>&1 || true
    log_to_file "Sudo timestamp invalidated"
  fi
}

test_sudo() {
  # Test if sudo is currently available without prompting
  if sudo -n true 2>/dev/null; then
    return 0
  fi
  return 1
}

# -----------------------------------------------------------------------------
# Universal Array Processing Functions
# -----------------------------------------------------------------------------

# Apply defaults from array
# Array format: "domain|key|value|type"
# Special: "-g" for global domain, "-currentHost|domain" for currentHost writes
# Special: "__HOME__" in value is replaced with $HOME
# Usage: apply_defaults false "${DEFAULTS_USER[@]}" or apply_defaults true "${DEFAULTS_ADMIN[@]}"
apply_defaults() {
  local use_sudo=$1
  shift
  local defaults_arr=("$@")
  local success_count=0
  local fail_count=0
  local total=${#defaults_arr[@]}
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  local entry domain key value dtype
  for entry in "${defaults_arr[@]}"; do
    # Skip empty entries
    [[ -z "$entry" ]] && continue
    
    # Parse entry
    IFS='|' read -r domain key value dtype <<< "$entry"
    
    # Replace __HOME__ placeholder
    value="${value//__HOME__/$HOME}"
    
    # Build defaults command
    local cmd_args=()
    local is_currenthost=false
    
    # Check for -currentHost prefix
    if [[ "$domain" == "-currentHost" ]]; then
      # Format: -currentHost|actual_domain|key|value|type
      is_currenthost=true
      IFS='|' read -r _ domain key value dtype <<< "$entry"
      value="${value//__HOME__/$HOME}"
    fi
    
    # Determine type flag
    local type_flag=""
    case "$dtype" in
      bool)   type_flag="-bool" ;;
      string) type_flag="-string" ;;
      int)    type_flag="-int" ;;
      float)  type_flag="-float" ;;
      *)      type_flag="-string" ;;
    esac
    
    # Build and execute command
    local desc="Set $domain $key"
    local result=0
    
    if [[ "$is_currenthost" == "true" ]]; then
      if [[ "$use_sudo" == "true" ]]; then
        sudo -n defaults -currentHost write "$domain" "$key" "$type_flag" "$value" >> "$LOG_FILE" 2>&1 || result=1
      else
        defaults -currentHost write "$domain" "$key" "$type_flag" "$value" >> "$LOG_FILE" 2>&1 || result=1
      fi
    else
      if [[ "$use_sudo" == "true" ]]; then
        sudo -n defaults write "$domain" "$key" "$type_flag" "$value" >> "$LOG_FILE" 2>&1 || result=1
      else
        defaults write "$domain" "$key" "$type_flag" "$value" >> "$LOG_FILE" 2>&1 || result=1
      fi
    fi
    
    if [[ $result -eq 0 ]]; then
      log_success "$desc = $value"
      ((success_count++))
    else
      log_error "$desc"
      ((fail_count++))
    fi
  done
  
  echo "$success_count/$total"
  return $fail_count
}

# Revert defaults from array (delete the keys)
# Usage: revert_defaults false "${DEFAULTS_USER[@]}" or revert_defaults true "${DEFAULTS_ADMIN[@]}"
revert_defaults() {
  local use_sudo=$1
  shift
  local defaults_arr=("$@")
  local success_count=0
  local total=${#defaults_arr[@]}
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  local entry domain key value dtype
  for entry in "${defaults_arr[@]}"; do
    [[ -z "$entry" ]] && continue
    
    IFS='|' read -r domain key value dtype <<< "$entry"
    
    local is_currenthost=false
    if [[ "$domain" == "-currentHost" ]]; then
      is_currenthost=true
      IFS='|' read -r _ domain key value dtype <<< "$entry"
    fi
    
    local desc="Revert $domain $key"
    
    if [[ "$is_currenthost" == "true" ]]; then
      if [[ "$use_sudo" == "true" ]]; then
        sudo -n defaults -currentHost delete "$domain" "$key" >> "$LOG_FILE" 2>&1 && ((success_count++)) || log_warn "$desc"
      else
        defaults -currentHost delete "$domain" "$key" >> "$LOG_FILE" 2>&1 && ((success_count++)) || log_warn "$desc"
      fi
    else
      if [[ "$use_sudo" == "true" ]]; then
        sudo -n defaults delete "$domain" "$key" >> "$LOG_FILE" 2>&1 && ((success_count++)) || log_warn "$desc"
      else
        defaults delete "$domain" "$key" >> "$LOG_FILE" 2>&1 && ((success_count++)) || log_warn "$desc"
      fi
    fi
  done
  
  echo "$success_count/$total"
}

# Apply Safari defaults - handles sandboxed container on macOS 14+ (Sonoma/Sequoia)
# Usage: apply_safari_defaults "${SAFARI_DEFAULTS[@]}"
apply_safari_defaults() {
  local safari_settings=("$@")
  local success_count=0
  local fail_count=0
  local total=${#safari_settings[@]}
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  # Determine the correct domain/path based on macOS version
  # macOS 14+ (Sonoma/Sequoia) uses sandboxed container
  local safari_domain="com.apple.Safari"
  local safari_container="${HOME}/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"
  local use_container=false
  
  if macos_version_at_least 14; then
    use_container=true
    log_verbose "macOS 14+ detected, using Safari container path"
    
    # Ensure Safari container exists
    if [[ ! -f "$safari_container" ]]; then
      log_warn "Safari preferences file not found at $safari_container"
      log_warn "Safari may need to be launched first to create preferences"
      echo "0/$total"
      return 1
    fi
  fi
  
  local entry key value dtype
  for entry in "${safari_settings[@]}"; do
    [[ -z "$entry" ]] && continue
    
    IFS='|' read -r key value dtype <<< "$entry"
    
    # Determine type flag
    local type_flag=""
    case "$dtype" in
      bool)   type_flag="-bool" ;;
      string) type_flag="-string" ;;
      int)    type_flag="-int" ;;
      float)  type_flag="-float" ;;
      *)      type_flag="-string" ;;
    esac
    
    local desc="Set Safari $key"
    local result=0
    
    if [[ "$use_container" == "true" ]]; then
      # For macOS 14+, write directly to the container plist
      defaults write "$safari_container" "$key" "$type_flag" "$value" >> "$LOG_FILE" 2>&1 || result=1
    else
      # For older macOS, use the standard domain
      defaults write "$safari_domain" "$key" "$type_flag" "$value" >> "$LOG_FILE" 2>&1 || result=1
    fi
    
    if [[ $result -eq 0 ]]; then
      log_success "$desc = $value"
      ((success_count++))
    else
      log_error "$desc"
      ((fail_count++))
    fi
  done
  
  echo "$success_count/$total"
  return $fail_count
}

# Revert Safari defaults
# Usage: revert_safari_defaults "${SAFARI_DEFAULTS[@]}"
revert_safari_defaults() {
  local safari_settings=("$@")
  local success_count=0
  local total=${#safari_settings[@]}
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  local safari_domain="com.apple.Safari"
  local safari_container="${HOME}/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"
  local use_container=false
  
  if macos_version_at_least 14; then
    use_container=true
    if [[ ! -f "$safari_container" ]]; then
      echo "0/$total"
      return 0
    fi
  fi
  
  local entry key value dtype
  for entry in "${safari_settings[@]}"; do
    [[ -z "$entry" ]] && continue
    
    IFS='|' read -r key value dtype <<< "$entry"
    local desc="Revert Safari $key"
    
    if [[ "$use_container" == "true" ]]; then
      defaults delete "$safari_container" "$key" >> "$LOG_FILE" 2>&1 && ((success_count++)) || log_warn "$desc"
    else
      defaults delete "$safari_domain" "$key" >> "$LOG_FILE" 2>&1 && ((success_count++)) || log_warn "$desc"
    fi
  done
  
  echo "$success_count/$total"
}

# Install Homebrew formulae from array
# Usage: install_brew_formulae "${BREW_FORMULAE[@]}"
install_brew_formulae() {
  local formulae=("$@")
  local success_count=0
  local fail_count=0
  local total=${#formulae[@]}
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  # Try to find brew if not in PATH
  local brew_cmd=""
  if command -v brew >/dev/null 2>&1; then
    brew_cmd="brew"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew_cmd="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_cmd="/usr/local/bin/brew"
  else
    log_warn "Homebrew not installed, skipping formulae"
    echo "0/$total"
    return 1
  fi
  
  log_verbose "Using brew at: $brew_cmd"
  log_verbose "Installing formulae: ${formulae[*]}"
  
  local formula
  for formula in "${formulae[@]}"; do
    [[ -z "$formula" ]] && continue
    
    log_verbose "Installing formula: $formula"
    if "$brew_cmd" install "$formula" >> "$LOG_FILE" 2>&1; then
      log_success "Install formula: $formula"
      ((success_count++))
    else
      log_error "Install formula: $formula"
      ((fail_count++))
    fi
  done
  
  echo "$success_count/$total"
  return $fail_count
}

# Install Homebrew casks from array
# Usage: install_brew_casks "${BREW_CASKS[@]}"
install_brew_casks() {
  local casks=("$@")
  local success_count=0
  local fail_count=0
  local total=${#casks[@]}
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  # Try to find brew if not in PATH
  local brew_cmd=""
  if command -v brew >/dev/null 2>&1; then
    brew_cmd="brew"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew_cmd="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_cmd="/usr/local/bin/brew"
  else
    log_warn "Homebrew not installed, skipping casks"
    echo "0/$total"
    return 1
  fi
  
  log_verbose "Using brew at: $brew_cmd"
  log_verbose "Installing casks: ${casks[*]}"
  
  local cask
  for cask in "${casks[@]}"; do
    [[ -z "$cask" ]] && continue
    
    # Refresh sudo before each cask (some have pkg installers that need sudo)
    if [[ -n "${SUDO_PASSWORD_FILE:-}" && -f "$SUDO_PASSWORD_FILE" ]]; then
      cat "$SUDO_PASSWORD_FILE" | sudo -S -v >/dev/null 2>&1 || true
    fi
    
    log_verbose "Installing cask: $cask"
    if "$brew_cmd" install --cask "$cask" >> "$LOG_FILE" 2>&1; then
      log_success "Install cask: $cask"
      ((success_count++))
    else
      log_error "Install cask: $cask"
      ((fail_count++))
    fi
  done
  
  echo "$success_count/$total"
  return $fail_count
}

# Install MAS apps from array
# Array format: "app_id|App Name"
# Usage: install_mas_apps "${MAS_APPS[@]}"
install_mas_apps() {
  local apps=("$@")
  local success_count=0
  local fail_count=0
  local total=${#apps[@]}
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  # Try to find mas if not in PATH
  local mas_cmd=""
  if command -v mas >/dev/null 2>&1; then
    mas_cmd="mas"
  elif [[ -x /opt/homebrew/bin/mas ]]; then
    mas_cmd="/opt/homebrew/bin/mas"
  elif [[ -x /usr/local/bin/mas ]]; then
    mas_cmd="/usr/local/bin/mas"
  else
    log_warn "mas not installed, skipping App Store apps"
    echo "0/$total"
    return 1
  fi
  
  local entry app_id app_name
  for entry in "${apps[@]}"; do
    [[ -z "$entry" ]] && continue
    
    app_id="${entry%%|*}"
    app_name="${entry#*|}"
    
    if [[ -z "$app_id" || "$app_id" == "$app_name" ]]; then
      log_warn "Invalid MAS entry: $entry"
      ((fail_count++))
      continue
    fi
    
    if "$mas_cmd" install "$app_id" >> "$LOG_FILE" 2>&1; then
      log_success "Install App Store: $app_name"
      ((success_count++))
    else
      log_error "Install App Store: $app_name"
      ((fail_count++))
    fi
  done
  
  echo "$success_count/$total"
  return $fail_count
}

# Get dockutil command path
get_dockutil_cmd() {
  if command -v dockutil >/dev/null 2>&1; then
    echo "dockutil"
  elif [[ -x /opt/homebrew/bin/dockutil ]]; then
    echo "/opt/homebrew/bin/dockutil"
  elif [[ -x /usr/local/bin/dockutil ]]; then
    echo "/usr/local/bin/dockutil"
  else
    echo ""
  fi
}

# Verify dock configuration by checking if expected items are present
# Returns 0 if dock matches expected items, 1 otherwise
verify_dock() {
  local items=("$@")
  local dockutil_cmd
  dockutil_cmd=$(get_dockutil_cmd)
  
  if [[ -z "$dockutil_cmd" ]]; then
    return 1
  fi
  
  # Get current dock items
  local current_dock
  current_dock=$("$dockutil_cmd" --list 2>/dev/null | cut -f1)
  
  # Check if each expected app is in the dock
  local item app_name
  local missing=0
  for item in "${items[@]}"; do
    [[ -z "$item" ]] && continue
    [[ "$item" == "SPACER" ]] && continue
    
    # Extract app name from path
    app_name=$(basename "$item" .app)
    
    if ! echo "$current_dock" | grep -q "$app_name"; then
      log_verbose "Dock verification: missing $app_name"
      ((missing++))
    fi
  done
  
  if [[ $missing -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Configure dock from array with retry logic
# Usage: configure_dock "${DOCK_ITEMS[@]}"
configure_dock() {
  local items=("$@")
  local success_count=0
  local total=${#items[@]}
  local max_retries=5
  local retry=0
  
  if [[ $total -eq 0 ]]; then
    echo "0/0"
    return 0
  fi
  
  # Try to find dockutil if not in PATH
  local dockutil_cmd
  dockutil_cmd=$(get_dockutil_cmd)
  
  if [[ -z "$dockutil_cmd" ]]; then
    log_warn "dockutil not installed, skipping dock configuration"
    echo "0/$total"
    return 1
  fi
  
  while [[ $retry -lt $max_retries ]]; do
    success_count=0
    
    if [[ $retry -gt 0 ]]; then
      log_verbose "Dock configuration retry $retry/$max_retries"
      sleep 2
    fi
    
    # Clear existing dock items
    "$dockutil_cmd" --remove all --no-restart >> "$LOG_FILE" 2>&1
    if [[ $retry -eq 0 ]]; then
      log_success "Cleared dock items"
    fi
    
    local item
    for item in "${items[@]}"; do
      [[ -z "$item" ]] && continue
      
      if [[ "$item" == "SPACER" ]]; then
        if "$dockutil_cmd" --add '' --type spacer --section apps --no-restart >> "$LOG_FILE" 2>&1; then
          if [[ $retry -eq 0 ]]; then
            log_success "Add dock spacer"
          fi
          ((success_count++))
        else
          if [[ $retry -eq 0 ]]; then
            log_warn "Add dock spacer"
          fi
        fi
      elif [[ -e "$item" ]]; then
        if "$dockutil_cmd" --add "$item" --no-restart >> "$LOG_FILE" 2>&1; then
          if [[ $retry -eq 0 ]]; then
            log_success "Add dock item: $item"
          fi
          ((success_count++))
        else
          if [[ $retry -eq 0 ]]; then
            log_warn "Add dock item: $item"
          fi
        fi
      else
        if [[ $retry -eq 0 ]]; then
          log_warn "Dock item not found: $item"
        fi
      fi
    done
    
    # Restart Dock to apply changes
    killall Dock 2>/dev/null || true
    sleep 2
    
    # Verify the dock configuration
    if verify_dock "${items[@]}"; then
      log_verbose "Dock configuration verified successfully"
      echo "$success_count/$total"
      return 0
    fi
    
    ((retry++))
    log_warn "Dock configuration verification failed, attempt $retry/$max_retries"
  done
  
  # Return result even if verification failed after all retries
  log_error "Dock configuration failed after $max_retries attempts"
  echo "$success_count/$total"
  return 1
}

# Filter dock items array to only existing apps
filter_dock_items() {
  local filtered=()
  local missing=()
  
  local item
  for item in "${DOCK_ITEMS[@]}"; do
    if [[ "$item" == "SPACER" ]]; then
      filtered+=("$item")
    elif [[ -e "$item" ]]; then
      filtered+=("$item")
    else
      missing+=("$item")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Dock items not found (will be skipped):"
    for item in "${missing[@]}"; do
      log_warn "  - $item"
    done
  fi
  
  DOCK_ITEMS=("${filtered[@]}")
}

# -----------------------------------------------------------------------------
# Apple ID Check
# -----------------------------------------------------------------------------

check_appleid_signed_in() {
  # Check if user is signed into App Store
  # This checks for the presence of an account identifier
  if defaults read com.apple.appstore AccountIdentifier &>/dev/null 2>&1; then
    return 0  # Signed in
  fi
  
  # Alternative check using mas (try to find it if not in PATH)
  local mas_cmd=""
  if command -v mas >/dev/null 2>&1; then
    mas_cmd="mas"
  elif [[ -x /opt/homebrew/bin/mas ]]; then
    mas_cmd="/opt/homebrew/bin/mas"
  elif [[ -x /usr/local/bin/mas ]]; then
    mas_cmd="/usr/local/bin/mas"
  fi
  
  if [[ -n "$mas_cmd" ]]; then
    if "$mas_cmd" account &>/dev/null 2>&1; then
      return 0  # Signed in
    fi
  fi
  
  return 1  # Not signed in
}

# -----------------------------------------------------------------------------
# Installation Functions
# -----------------------------------------------------------------------------

ensure_xcode_cli_tools() {
  if /usr/bin/xcode-select -p >/dev/null 2>&1; then
    log_success "Xcode Command Line Tools already installed"
    if [[ "$ACCEPT_XCODE_LICENSE" == "true" ]]; then
      accept_xcode_license
    fi
    return 0
  fi
  
  log_verbose "Requesting Xcode Command Line Tools installation..."
  /usr/bin/xcode-select --install >> "$LOG_FILE" 2>&1 || true
  
  # Wait for installation to complete
  local wait_count=0
  while ! /usr/bin/xcode-select -p >/dev/null 2>&1; do
    if [[ $wait_count -eq 0 ]]; then
      printf "\n    Waiting for Xcode Command Line Tools installation...\n"
    fi
    sleep 10
    ((wait_count++))
    if [[ $wait_count -gt 60 ]]; then
      log_error "Xcode Command Line Tools installation timed out"
      return 1
    fi
  done
  
  log_success "Xcode Command Line Tools installed"
  
  if [[ "$ACCEPT_XCODE_LICENSE" == "true" ]]; then
    accept_xcode_license
  fi
  
  return 0
}

accept_xcode_license() {
  if ! command -v xcodebuild >/dev/null 2>&1; then
    log_warn "xcodebuild not available, cannot accept license"
    return 0
  fi
  
  ensure_sudo
  if sudo -n /usr/bin/xcodebuild -license accept >> "$LOG_FILE" 2>&1; then
    log_success "Xcode license accepted"
  else
    log_warn "Could not accept Xcode license"
  fi
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log_success "Homebrew already installed"
    return 0
  fi
  
  if ! command -v /bin/bash >/dev/null 2>&1; then
    log_error "bash not available for Homebrew installation"
    return 1
  fi
  
  log_verbose "Installing Homebrew..."
  ensure_sudo
  
  # Run Homebrew installer
  if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" 2>&1; then
    log_success "Homebrew installed"
  else
    log_error "Homebrew installation failed"
    return 1
  fi
  
  # Add Homebrew to PATH for this session (export to ensure subshells inherit)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    export PATH="/opt/homebrew/bin:$PATH"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    export PATH="/usr/local/bin:$PATH"
  fi
  
  # Verify brew is now accessible
  if command -v brew >/dev/null 2>&1; then
    log_verbose "Homebrew PATH configured: $(command -v brew)"
  else
    log_warn "Homebrew installed but not in PATH"
  fi
  
  return 0
}

# -----------------------------------------------------------------------------
# System Settings Functions
# -----------------------------------------------------------------------------

close_system_settings() {
  # Close System Preferences (older macOS)
  osascript -e 'tell application "System Preferences" to quit' >> "$LOG_FILE" 2>&1 || true
  # Close System Settings (macOS Ventura+)
  osascript -e 'tell application "System Settings" to quit' >> "$LOG_FILE" 2>&1 || true
  log_success "Closed System Settings"
}

ensure_safari_initialized() {
  local safari_container="${HOME}/Library/Containers/com.apple.Safari"
  
  if [[ -d "$safari_container" ]]; then
    log_success "Safari already initialized"
    return 0
  fi
  
  log_verbose "Initializing Safari..."
  
  # Launch Safari
  open -a "Safari" >> "$LOG_FILE" 2>&1 || true
  sleep 3
  
  # Quit Safari
  osascript -e 'tell application "Safari" to quit' >> "$LOG_FILE" 2>&1 || true
  sleep 2
  
  if [[ -d "$safari_container" ]]; then
    log_success "Safari initialized"
    return 0
  else
    log_warn "Safari container not created"
    return 1
  fi
}

# Unhide ~/Library folder
unhide_library() {
  run_optional "Unhide ~/Library" chflags nohidden "$HOME/Library"
  
  if xattr -p com.apple.FinderInfo "$HOME/Library" >/dev/null 2>&1; then
    run_optional "Remove FinderInfo xattr from ~/Library" xattr -d com.apple.FinderInfo "$HOME/Library"
  fi
}

restart_affected_apps() {
  local restarted=0
  
  # Restart Finder
  if killall Finder >> "$LOG_FILE" 2>&1; then
    log_success "Restarted Finder"
    ((restarted++))
  fi
  
  # Restart Dock
  if killall Dock >> "$LOG_FILE" 2>&1; then
    log_success "Restarted Dock"
    ((restarted++))
  fi
  
  # Don't restart Safari if it's not running
  if pgrep -x "Safari" >/dev/null 2>&1; then
    killall Safari >> "$LOG_FILE" 2>&1 || true
    log_success "Restarted Safari"
    ((restarted++))
  fi
  
  echo "$restarted apps"
}

# -----------------------------------------------------------------------------
# Default Browser
# -----------------------------------------------------------------------------

set_default_browser() {
  if [[ -z "$DEFAULT_BROWSER" ]]; then
    log_skip "No default browser configured"
    return 0
  fi
  
  local browser_app="/Applications/${DEFAULT_BROWSER}.app"
  
  if [[ ! -d "$browser_app" ]]; then
    log_error "Browser not found: $browser_app"
    return 1
  fi
  
  log_verbose "Setting default browser to: $DEFAULT_BROWSER"
  
  # Launch Chrome with --make-default-browser flag
  # This triggers Chrome's own default browser prompt/setting
  if [[ "$DEFAULT_BROWSER" == "Google Chrome" ]]; then
    open -a "Google Chrome" --args --make-default-browser >> "$LOG_FILE" 2>&1
    sleep 2
    log_success "Triggered Chrome default browser setting"
    return 0
  fi
  
  # For other browsers, just log that manual setting is needed
  log_warn "Please set $DEFAULT_BROWSER as default browser manually in System Settings"
  return 0
}

# -----------------------------------------------------------------------------
# Client Profiles
# -----------------------------------------------------------------------------

apply_client_profile() {
  if [[ -z "$CLIENT_PROFILE" ]]; then
    CLIENT_PROFILE="default"
  fi
  
  case "$CLIENT_PROFILE" in
    default)
      BREW_FORMULAE=(
        "mas"
        "dockutil"
      )
      
      BREW_CASKS=(
        "1password"
        "slack"
        "google-chrome"
        "google-drive"
        "whatsapp"
      )
      ;;
    # Add custom client profiles here:
    # clientname)
    #   BREW_CASKS+=(
    #     "custom-app"
    #   )
    #   ;;
    *)
      log_error "Unknown client profile: $CLIENT_PROFILE"
      exit 1
      ;;
  esac
  
  log_verbose "Loaded client profile: $CLIENT_PROFILE"
}

# -----------------------------------------------------------------------------
# Summary and Usage
# -----------------------------------------------------------------------------

show_summary() {
  printf "\n"
  printf "==================\n"
  printf "Summary\n"
  printf "==================\n"
  
  local total_issues=$((${#FAILURES[@]} + ${#SKIPPED[@]}))
  
  if [[ ${#FAILURES[@]} -eq 0 ]]; then
    printf "All tasks completed successfully.\n"
  else
    printf "Completed with %d error(s):\n" "${#FAILURES[@]}"
    for failure in "${FAILURES[@]}"; do
      printf "  - %s\n" "$failure"
    done
  fi
  
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf "\nWarnings (%d):\n" "${#WARNINGS[@]}"
    for warning in "${WARNINGS[@]}"; do
      printf "  - %s\n" "$warning"
    done
  fi
  
  if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    printf "\nSkipped (%d):\n" "${#SKIPPED[@]}"
    for skipped in "${SKIPPED[@]}"; do
      printf "  - %s\n" "$skipped"
    done
  fi
  
  printf "\nLog file: %s\n" "$LOG_FILE"
}

show_version() {
  printf "macOS Setup Script %s\n" "$VERSION"
}

show_usage() {
  cat << EOF
macOS Setup Script $VERSION

Usage: $(basename "$0") [OPTIONS] [CLIENT_NAME]

Options:
  --revert               Revert defaults set by this script
  --client NAME          Apply client profile (default: default)
  --accept-xcode-license Accept Xcode license after installation
  -v, --version          Show version number
  -h, --help             Show this help message

Client Profiles:
  Edit the apply_client_profile() function to add custom profiles.

Examples:
  $(basename "$0")                    # Run with default profile
  $(basename "$0") --client acme      # Run with 'acme' profile
  $(basename "$0") --revert           # Revert all defaults
EOF
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --revert)
        REVERT_DEFAULTS=true
        shift
        ;;
      --client)
        shift
        if [[ -z "${1:-}" ]]; then
          printf "Error: Missing value for --client\n" >&2
          show_usage
          exit 1
        fi
        CLIENT_PROFILE="$1"
        shift
        ;;
      --client=*)
        CLIENT_PROFILE="${1#*=}"
        shift
        ;;
      --accept-xcode-license)
        ACCEPT_XCODE_LICENSE=true
        shift
        ;;
      -v|--version)
        show_version
        exit 0
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      -*)
        printf "Error: Unknown option: %s\n" "$1" >&2
        show_usage
        exit 1
        ;;
      *)
        if [[ -z "$CLIENT_PROFILE" ]]; then
          CLIENT_PROFILE="$1"
        else
          printf "Error: Unexpected argument: %s\n" "$1" >&2
          show_usage
          exit 1
        fi
        shift
        ;;
    esac
  done
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

main() {
  # Setup cleanup trap
  trap cleanup_sudo EXIT
  
  # Parse command line arguments
  parse_args "$@"
  
  # Apply client profile (sets BREW_FORMULAE, BREW_CASKS, etc.)
  apply_client_profile
  
  # Initialize log file
  mkdir -p "$(dirname "$LOG_FILE")"
  printf "macOS Setup Script %s - Started %s\n" "$VERSION" "$(date)" > "$LOG_FILE"
  printf "Client Profile: %s\n" "$CLIENT_PROFILE" >> "$LOG_FILE"
  printf "Revert Mode: %s\n\n" "$REVERT_DEFAULTS" >> "$LOG_FILE"
  
  # Print header
  printf "\n"
  printf "macOS Setup Script %s\n" "$VERSION"
  printf "========================\n"
  printf "Log file: %s\n\n" "$LOG_FILE"
  
  # -------------------------------------------------------------------------
  # Step 1: Initialize sudo
  # -------------------------------------------------------------------------
  begin_step "Initializing sudo"
  if init_sudo; then
    step_ok
  else
    step_fail "could not obtain credentials"
  fi
  
  # -------------------------------------------------------------------------
  # Step 2: Install Xcode Command Line Tools
  # -------------------------------------------------------------------------
  begin_step "Installing Xcode CLI Tools"
  if ensure_xcode_cli_tools; then
    step_ok
  else
    step_fail
  fi
  
  # -------------------------------------------------------------------------
  # Step 3: Install Homebrew
  # -------------------------------------------------------------------------
  begin_step "Installing Homebrew"
  if install_homebrew; then
    step_ok
  else
    step_fail
  fi
  
  # -------------------------------------------------------------------------
  # Step 4: Install Homebrew formulae
  # -------------------------------------------------------------------------
  begin_step "Installing Homebrew formulae"
  if [[ ${#BREW_FORMULAE[@]} -eq 0 ]]; then
    step_skip "none configured"
  else
    # Refresh sudo before installation
    refresh_sudo
    result=$(install_brew_formulae "${BREW_FORMULAE[@]}")
    if [[ $? -eq 0 ]]; then
      step_ok "$result"
    else
      step_fail "$result"
    fi
  fi
  
  # -------------------------------------------------------------------------
  # Step 5: Install Homebrew casks
  # -------------------------------------------------------------------------
  begin_step "Installing Homebrew casks"
  if [[ ${#BREW_CASKS[@]} -eq 0 ]]; then
    step_skip "none configured"
  else
    # Refresh sudo before cask installation (some casks need sudo for pkg installers)
    refresh_sudo
    result=$(install_brew_casks "${BREW_CASKS[@]}")
    if [[ $? -eq 0 ]]; then
      step_ok "$result"
    else
      step_fail "$result"
    fi
  fi
  
  # -------------------------------------------------------------------------
  # Step 6: Check Apple ID and install MAS apps
  # -------------------------------------------------------------------------
  begin_step "Installing App Store apps"
  if [[ ${#MAS_APPS[@]} -eq 0 ]]; then
    step_skip "none configured"
  elif ! command -v mas >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/mas ]] && [[ ! -x /usr/local/bin/mas ]]; then
    step_skip "mas not installed"
    log_skip "App Store apps (mas not installed)"
  elif ! check_appleid_signed_in; then
    step_skip "not signed in"
    log_skip "App Store apps (Apple ID not signed in)"
  else
    result=$(install_mas_apps "${MAS_APPS[@]}")
    if [[ $? -eq 0 ]]; then
      step_ok "$result"
    else
      step_fail "$result"
    fi
  fi
  
  # -------------------------------------------------------------------------
  # Step 7: Close System Settings
  # -------------------------------------------------------------------------
  begin_step "Closing System Settings"
  close_system_settings
  step_ok
  
  # -------------------------------------------------------------------------
  # Step 8: Initialize Safari
  # -------------------------------------------------------------------------
  begin_step "Initializing Safari"
  if ensure_safari_initialized; then
    step_ok
  else
    step_skip "could not initialize"
  fi
  
  # -------------------------------------------------------------------------
  # Step 9: Apply user defaults
  # -------------------------------------------------------------------------
  begin_step "Applying user defaults"
  if [[ "$REVERT_DEFAULTS" == "true" ]]; then
    result=$(revert_defaults false "${DEFAULTS_USER[@]}")
    step_ok "reverted $result"
  else
    # Also unhide ~/Library
    unhide_library
    result=$(apply_defaults false "${DEFAULTS_USER[@]}")
    if [[ $? -eq 0 ]]; then
      step_ok "$result"
    else
      step_fail "$result"
    fi
  fi
  
  # -------------------------------------------------------------------------
  # Step 10: Apply Safari defaults (separate due to sandboxed container on macOS 14+)
  # -------------------------------------------------------------------------
  begin_step "Applying Safari defaults"
  if [[ ${#SAFARI_DEFAULTS[@]} -eq 0 ]]; then
    step_skip "none configured"
  elif [[ "$REVERT_DEFAULTS" == "true" ]]; then
    result=$(revert_safari_defaults "${SAFARI_DEFAULTS[@]}")
    step_ok "reverted $result"
  else
    result=$(apply_safari_defaults "${SAFARI_DEFAULTS[@]}")
    if [[ $? -eq 0 ]]; then
      step_ok "$result"
    else
      step_fail "$result"
    fi
  fi
  
  # -------------------------------------------------------------------------
  # Step 11: Apply admin defaults
  # -------------------------------------------------------------------------
  begin_step "Applying admin defaults"
  if [[ ${#DEFAULTS_ADMIN[@]} -eq 0 ]]; then
    step_skip "none configured"
  elif [[ "$REVERT_DEFAULTS" == "true" ]]; then
    ensure_sudo
    result=$(revert_defaults true "${DEFAULTS_ADMIN[@]}")
    step_ok "reverted $result"
  else
    ensure_sudo
    result=$(apply_defaults true "${DEFAULTS_ADMIN[@]}")
    if [[ $? -eq 0 ]]; then
      step_ok "$result"
    else
      step_fail "$result"
    fi
  fi
  
  # -------------------------------------------------------------------------
  # Step 12: Configure Dock (with retry and verification)
  # -------------------------------------------------------------------------
  begin_step "Configuring Dock"
  filter_dock_items
  if [[ ${#DOCK_ITEMS[@]} -eq 0 ]]; then
    step_skip "no items configured"
  elif ! command -v dockutil >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/dockutil ]] && [[ ! -x /usr/local/bin/dockutil ]]; then
    step_skip "dockutil not installed"
    log_skip "Dock configuration (dockutil not installed)"
  else
    result=$(configure_dock "${DOCK_ITEMS[@]}")
    if [[ $? -eq 0 ]]; then
      step_ok "$result items"
    else
      step_fail "$result items (verification failed)"
    fi
  fi
  
  # -------------------------------------------------------------------------
  # Step 13: Set default browser
  # -------------------------------------------------------------------------
  begin_step "Setting default browser"
  if [[ -z "$DEFAULT_BROWSER" ]]; then
    step_skip "not configured"
  elif set_default_browser; then
    step_ok "$DEFAULT_BROWSER"
  else
    step_fail "$DEFAULT_BROWSER not found"
  fi
  
  # -------------------------------------------------------------------------
  # Step 14: Restart affected apps
  # -------------------------------------------------------------------------
  begin_step "Restarting affected apps"
  result=$(restart_affected_apps)
  step_ok "$result"
  
  # -------------------------------------------------------------------------
  # Step 15: Complete
  # -------------------------------------------------------------------------
  begin_step "Finalizing"
  step_ok
  
  # Show summary
  show_summary
}

# Run main function
main "$@"
