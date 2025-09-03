#!/usr/bin/env bash
#
# Cloud Ignore Files - Sync with Power Nap Protection  
# v2.0.0
#
# Bidirectional sync with lock screen detection, watch mode recovery, 
# and custom Dropbox-compatible unison binaries. Pauses sync automatically 
# during Power Nap when screen is locked.
#
# Usage:
#  --install   Install/update sync with architecture detection and custom binaries
#  --update    Same as --install  
#  --uninstall Remove sync service and clean up files
#  --info      Show configuration and status
#
# Features: Lock detection • Session logging • Watch recovery • Custom binaries

# Adjust the paths to match your system (do not end the path with /).
# Path to local (working) projects folder
local_path="${HOME}/github"

# Path to cloud projects folder (node_modules, etc. are omitted).
#
# Note: if you're using iCloud on a system before Sierra, the Documents folder
# can be found at "${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
cloud_path="${HOME}/Dropbox/github-mirror"

# List of files/patterns to ignore (one per line). These will be joined with commas for Unison.
# Example: adding a line "*.log" will ignore any files ending with `*.log`.
# For more details see: http://www.cis.upenn.edu/~bcpierce/unison/download/releases/stable/unison-manual.html#ignore
ignore_files=(
  # General
  "*.log"
  "build"
  "dist"
  "tmp"
  "temp"
  "var"
  ".cache"
  "cache"
  "vendor"
  "*.tmp.*"

  # OSX
  ".DS_Store"
  ".Spotlight-V100"
  ".DocumentRevisions-V100"
  ".TemporaryItems"
  ".Trashes"
  ".fseventsd"
  
  # IDE
  ".vscode"
  ".idea"

  # Rust
  "target"

  # Node / JavaScript
  "node_modules"
  "bower_components"
  ".nuxt"
  ".nuxt_webpack"
  ".next"

  # Python
  "__pycache__"
  "venv*"
  ".venv*"
)

# Unison flags (one per line for clarity and maintainability)
unison_flags=(
	  # Core settings
    "-batch"              # Non-interactive mode
    "-auto"               # Accept non-conflicting changes (yes, useful even with batch)
    "-times"              # Preserve modification times
    "-perms=0o111"        # Only sync executable bit
    "-links=true"         # Copy symbolic links

    # Safety CRITICAL - DISABLED: backup feature causes excessive disk writes DO NOT RE-ENABLE

    # Conflict resolution
    "-prefer=newer"       # Prefer newer file on conflict

    # Performance - REDUCED: Lower concurrency to reduce Dropbox temp file conflicts
    "-maxthreads=1"       # Single-threaded sync to avoid multiple temp files

    # Reliability
    "-retry=3"            # Retry failed synchronizations 3 times
    
    # Batch mode helpers  
    "-ignorecase=false"   # Case-sensitive (for git)
    "-confirmbigdel=false" # No prompts for deletions
)

##########################################################################
# No need to modify the code below, unless you know what you're doing :D #
##########################################################################

# Join ignore files into a comma-separated string for Unison's Name {a,b,c} syntax
ignore_files_joined="$(IFS=,; printf '%s' "${ignore_files[*]}")"

# Join unison flags into a space-separated string for command line
unison_flags_joined="${unison_flags[*]}"

# Path to script and launchd config.
base_path="${HOME}/.unison"
label="com.chrisblossom.projects.CloudSyncIgnore"

# Get brew exec directory (changes based on OS/architecture: Intel vs Apple Silicon)
brew_exec_dir="$(dirname "$(command -v brew)")"

# Architecture detection for custom unison binary
# Custom build changes temp files from .unison.tmp to .~unison.temp (Dropbox ignores .~ files)
# https://github.com/bcpierce00/unison/pull/447
arch=$(uname -m)
if [[ "$arch" == "arm64" ]]; then
    unison_binary="unison-silicon"
elif [[ "$arch" == "x86_64" ]]; then
    unison_binary="unison-intel"
fi

script_path="${base_path}/bin/unison-cloud-sync-ignore"
sync_once_path="${brew_exec_dir}/sync-mirror"
unison_path="${brew_exec_dir}/${unison_binary}"
plist_path="${HOME}/Library/LaunchAgents/${label}.plist"
log_file="${base_path}/cloudsyncignore.unison.log"
stdout_log="${base_path}/cloudsyncignore.stdout.log"
stderr_log="${base_path}/cloudsyncignore.stderr.log"

echo "** SYNC INFORMATION **"
echo "local_path: $local_path"
echo "cloud_path: $cloud_path"
echo "unison_binary: $unison_path (arch: $arch)"
echo "ignore_files: ${ignore_files_joined}"
echo "unison_flags: ${unison_flags_joined}"
echo "log_file: $log_file"
echo "stdout_log: $stdout_log"
echo "stderr_log: $stderr_log"
echo "script_path: $script_path"
echo "sync_once_path: $sync_once_path (in PATH)"
echo "plist_path: $plist_path"

# Version check
custom_ver=$("./$unison_binary" -version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
brew_ver=$(brew info unison 2>/dev/null | grep -E "^==> unison:" | awk '{print $4}')

if [[ -n "$custom_ver" ]]; then
  echo "custom_unison_version: $custom_ver"
fi

if [[ -n "$brew_ver" ]]; then
  echo "homebrew_unison_version: $brew_ver"
fi

if [[ -n "$custom_ver" && -n "$brew_ver" && "$custom_ver" != "$brew_ver" ]]; then
  echo ""
  echo "***************************************************"
  echo "WARNING: Custom unison version ($custom_ver) differs from Homebrew version ($brew_ver)"
  echo "Consider updating your custom binaries if sync issues occur."
  echo "***************************************************"
  echo ""
fi

echo ""

# Check if script is called with correct arguments.
if [[ ("$1" != "--install" && "$1" != "--update" && "$1" != "--uninstall") || -n "$2" ]] || [[ -z "$1" ]]; then
  echo "Usage: $0 [--install] [--update] [--uninstall]"
  exit 1
fi

# do not allow running as root
if [[ $EUID -eq 0 ]]; then
   echo "ERROR: $0 cannot be ran using sudo or as the root user. Manually remove files listed above and try again."
   exit 1
fi

# If config already exists, unload it before updating it.
if [ -f "$plist_path" ]; then
  echo "Unloading $plist_path"
  launchctl unload "$plist_path"
fi

if [[ "$1" == "--uninstall" ]]; then
  echo "Removing $script_path"
  rm -f "$script_path"
  echo "Removing $sync_once_path (from PATH)"
  rm -f "$sync_once_path"
  echo "Removing $plist_path"
  rm -f "$plist_path"

  echo "Removing $stdout_log"
  rm -f "$stdout_log"
  echo "Removing $stderr_log"
  rm -f "$stderr_log"

  echo "Removing $base_path/bin/ if the directory is empty"
  rmdir "$base_path/bin" 2>/dev/null
  echo "Removing $base_path/ if the directory is empty"
  rmdir "$base_path" 2>/dev/null

  echo ""
  echo "Sync script successfully removed. If you have any suggestions for improvement, please submit an issue on github."
  exit
fi

if [[ -z "$HOMEBREW_PREFIX" ]]; then
  echo "Homebrew is not installed. Install it (https://brew.sh) and try this script again."
  exit 1
fi

echo "creating directory $base_path/bin/"
mkdir -p "$base_path/bin"

# Copy custom unison binary
if [[ -n "$unison_binary" ]]; then
    cp "$unison_binary" "$unison_path"
fi

# Check for custom unison binary and fail if not found.
if [[ ! -f "$unison_path" ]]; then
  echo "Custom unison binary not found at $unison_path. Make sure $unison_binary was copied correctly."
  exit 1
fi

# Create/clear log files and fix log file permissions.
echo "(re)creating log files."
sh -c 'echo "" > $0' "$stdout_log"
sh -c 'echo "" > $0' "$stderr_log"

# Create actual files based of .template files.
echo "Creating $plist_path"
sed "s|{{LOCAL_PATH}}|${local_path}|;
     s|{{CLOUD_PATH}}|${cloud_path}|;
     s|{{SCRIPT_PATH}}|${script_path}|;
     s|{{LABEL}}|${label}|;
     s|{{LOG_FILE}}|${stdout_log}|;
     s|{{ERR_FILE}}|${stderr_log}|" plist.template > "$plist_path"

echo "Creating $script_path"
sed "s|{{INSTALLED_USER}}|${USER}|;
     s|{{BASE_PATH}}|${base_path}|;
     s|{{UNISON_PATH}}|${unison_path}|;
     s|{{UNISON_FLAGS}}|${unison_flags_joined}|;
     s|{{LOG_FILE}}|${log_file}|;
     s|{{IGNORE_FILES}}|${ignore_files_joined}|;
     s|{{LOCAL_PATH}}|${local_path}|;
     s|{{CLOUD_PATH}}|${cloud_path}|;" script.template > "$script_path"

echo "Creating $sync_once_path"
sed "s|{{INSTALLED_USER}}|${USER}|;
     s|{{BASE_PATH}}|${base_path}|;
     s|{{UNISON_PATH}}|${unison_path}|;
     s|{{UNISON_FLAGS}}|${unison_flags_joined}|;
     s|{{LOG_FILE}}|${log_file}|;
     s|{{IGNORE_FILES}}|${ignore_files_joined}|;
     s|{{LOCAL_PATH}}|${local_path}|;
     s|{{CLOUD_PATH}}|${cloud_path}|;" sync-once.template > "$sync_once_path"

chmod +x "$script_path" "$sync_once_path"

# Load launchd config.
echo "Loading $plist_path"
launchctl load "$plist_path"

echo ""
echo "Sync scripts created:"
echo "  - Watch script: $script_path (automatic sync on file changes)"
echo "  - Manual sync: $sync_once_path (available in PATH)"
echo ""
echo "The watch script will be triggered any time any files inside local or cloud project folders change."
echo "Run 'sync-mirror' from anywhere to manually sync."
