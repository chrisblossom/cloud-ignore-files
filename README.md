## Project Overview

Bidirectional sync for cloud services (Dropbox, iCloud) with Power Nap protection. Ignores build artifacts like `node_modules`, `target`, etc. while syncing your project files. Includes lock screen detection, watch mode recovery, session logging, and custom Dropbox-compatible temp files.

**Key Features**: Lock screen pauses sync • Watch mode auto-recovery • Session logging • Architecture-aware custom binaries • Dropbox-compatible temp files

## Key Commands

- **Install/Setup**: `./cloud-ignore-files.sh --install`
- **Update Configuration**: `./cloud-ignore-files.sh --update`
- **Uninstall**: `./cloud-ignore-files.sh --uninstall`

## Architecture

1. **Main Script** (`cloud-ignore-files.sh`): Installer/manager that detects your Mac's architecture, copies the right unison binary, configures sync paths and ignore patterns, and sets up a launchd service.

2. **Template Files**:
   - `plist.template`: launchd service configuration  
   - `script.template`: Main sync script with session monitoring and lock detection
   - `sync-once.template`: Manual sync command

3. **Generated Files**:
   - `~/.unison/bin/unison-cloud-sync-ignore`: The actual sync script
   - `sync-mirror`: Manual sync command (in PATH)
   - `~/Library/LaunchAgents/com.chrisblossom.projects.CloudSyncIgnore.plist`: launchd service
   - Log files in `~/.unison/`: 
     - `session.log`: Session start/stop events with timestamps
     - `cloudsyncignore.unison.log`: Unison sync activity  
     - `cloudsyncignore.stdout.log`, `cloudsyncignore.stderr.log`: Process output

## Configuration Variables

Key variables in `cloud-ignore-files.sh`:

- **`local_path`**: Local working projects directory, defaults to `${HOME}/github`
- **`cloud_path`**: Cloud-synced mirror directory, defaults to `${HOME}/Dropbox/github-mirror`
- **`ignore_files`** array: Files/patterns to exclude from sync like node_modules, target, .DS_Store

The ignore patterns are joined into a comma-separated string for Unison's `Name {a,b,c}` syntax.

## Custom Unison Binaries

The project automatically detects your Mac's architecture and uses the appropriate custom unison binary:

- **Apple Silicon**: `unison-silicon`
- **Intel Macs**: `unison-intel`

These get copied to your Homebrew bin directory during install. The main difference is temp file naming: `.unison.tmp` becomes `.~unison.temp` so Dropbox ignores them.

See: https://github.com/bcpierce00/unison/pull/447

## Dependencies

- **Custom [`unison`](https://github.com/bcpierce00/unison) binaries**: Included with modified temp file naming for Dropbox compatibility
- **[`unison-fsmonitor`](https://github.com/autozimu/unison-fsmonitor)**: Required for file watching capability
- **macOS with Homebrew**: Currently macOS-specific 
- **Full Disk Access**: For iCloud users, `/bin/bash` needs Full Disk Access permission

## How Syncing Works

### Core Sync Features
1. **Watch Mode**: Uses custom `unison` binary with `-repeat=watch` for continuous monitoring
2. **Bidirectional Sync**: Real-time sync between local and cloud directories  
3. **Conflict Resolution**: Prefers newer files on conflict (no duplicated files)
4. **File Attributes**: Preserves permissions and timestamps
5. **Smart Ignoring**: Excludes patterns like node_modules, build artifacts
6. **Dropbox Compatible**: Creates `.~unison.temp` files (ignored by Dropbox)

### Session Management
- **Lock Screen Detection**: Automatically pauses sync when screen locked
- **Watch Mode Recovery**: Detects failures, runs backup sync, restarts automatically
- **Session Logging**: Tracks all start/stop events in `~/.unison/session.log`
- **Signal Handling**: Graceful shutdown, manual restart with `kill -USR1 <pid>`

### Power Nap Protection
Lock your screen before walking away. Sync stops within 30 seconds and stays stopped during Power Nap. Unlocking resumes sync.

## Monitoring and Troubleshooting

### Check Logs
```bash
# Watch sync activity
tail -f ~/.unison/session.log
```



### Manual Controls
```bash
# Force sync restart (if needed for debugging)
kill -USR1 $(pgrep -f unison-cloud-sync-ignore)

# Stop sync service
launchctl unload ~/Library/LaunchAgents/com.chrisblossom.projects.CloudSyncIgnore.plist

# Start sync service  
launchctl load ~/Library/LaunchAgents/com.chrisblossom.projects.CloudSyncIgnore.plist
```

### Testing Changes

When modifying ignore patterns or paths:
1. Edit the variables at the top of `cloud-ignore-files.sh`
2. Run `./cloud-ignore-files.sh --update` to regenerate and reload config
3. Check logs in `~/.unison/` for any sync issues
