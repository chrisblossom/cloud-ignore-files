#!/usr/bin/env bash
#
# v1.0.0
#
# Usage:
#  - Call script to register sync script with launchd.
#  - Call with `--install` to install/update sync.
#  - Call with `--uninstall` to unregister from launchd and clean up files.

# Adjust the paths to match your system (do not end the path with /).
# Path to local (working) projects folder
local_path="${HOME}/github"

# Path to cloud projects folder (node_modules, etc. are omitted).
#
# Note: if you're using iCloud on a system before Sierra, the Documents folder
# can be found at "${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
cloud_path="${HOME}/Dropbox/github-mirror"

# Comma-separated list of files to ignore.
# Example: "node_modules,*.log" -> ignore all paths containing `node_modules` and any files ending with `*.log`.
# For more details see: http://www.cis.upenn.edu/~bcpierce/unison/download/releases/stable/unison-manual.html#ignore
ignore_files="node_modules,bower_components,*.log,.DS_Store,.Spotlight-V100,.Trashes,.fseventsd,build,dist,.vscode,.idea,tmp,temp,var,.cache,cache,vendor,.nuxt,.nuxt_webpack,.next"

##########################################################################
# No need to modify the code below, unless you know what you're doing :D #
##########################################################################

# Path to script and launchd config.
base_path="${HOME}/.unison"
label="com.chrisblossom.projects.CloudSyncIgnore"
script_path="${base_path}/bin/unison-cloud-sync-ignore"
plist_path="${HOME}/Library/LaunchAgents/${label}.plist"
output_log="${base_path}/cloudsyncignore.output.log"
error_log="${base_path}/cloudsyncignore.error.log"

echo "** SYNC INFORMATION **"
echo "local_path: $local_path"
echo "cloud_path: $cloud_path"
echo "ignore_files: $ignore_files"
echo "output_log: $output_log"
echo "error_log: $error_log"
echo "script_path: $script_path"
echo "plist_path: $plist_path"
echo -e "**********************\n"

# Check if script is called with correct arguments.
if [[ ("$1" != "--install" && "$1" != "--uninstall") || -n "$2" ]] || [[ -z "$1" ]]; then
  echo "Usage: $0 [--install] [--uninstall]"
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
  echo "Removing $plist_path"
  rm -f "$plist_path"

  echo "Removing $output_log"
  rm -f "$output_log"
  echo "Removing $error_log"
  rm -f "$error_log"

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

# Check for unison command and fail if not found.
if ! command -v unison >/dev/null 2>&1; then
  echo "Command 'unison' not found. Install it (brew install unison) and try this script again."
  exit 1
fi

echo "creating directory $base_path/bin/"
mkdir -p "$base_path/bin"

# Create/clear log files and fix log file permissions.
echo "(re)creating log files."
sh -c 'echo "" > $0' "$output_log"
sh -c 'echo "" > $0' "$error_log"

# Create actual files based of .template files.
echo "Creating $plist_path"
sed "s|{{LOCAL_PATH}}|${local_path}|;
     s|{{CLOUD_PATH}}|${cloud_path}|;
     s|{{SCRIPT_PATH}}|${script_path}|;
     s|{{LABEL}}|${label}|;
     s|{{LOG_FILE}}|${output_log}|;
     s|{{ERR_FILE}}|${error_log}|" plist.template > "$plist_path"

echo "Creating $script_path"
sed "s|{{UNISON_PATH}}|$(which unison)|;
     s|{{IGNORE_FILES}}|${ignore_files}|;
     s|{{LOCAL_PATH}}|${local_path}|;
     s|{{CLOUD_PATH}}|${cloud_path}|;" script.template > "$script_path"
chmod +x "$script_path"

# Load launchd config.
echo "Loading $plist_path"
launchctl load "$plist_path"

echo ""
echo "Sync script added. It will be triggered any time any of files inside local or cloud project folder changes."
