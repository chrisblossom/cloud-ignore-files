## Project Overview

This is a bidirectional sync utility that enables cloud sync services (like Dropbox, iCloud) to selectively ignore certain project files (like `node_modules`, `target`, etc.) while still syncing the rest of the project. It uses `unison` for bidirectional synchronization between a local working directory and a cloud-synced mirror.

## Key Commands

- **Install/Setup**: `./cloud-ignore-files.sh --install`
- **Update Configuration**: `./cloud-ignore-files.sh --update`
- **Uninstall**: `./cloud-ignore-files.sh --uninstall`

## Architecture

The system consists of:

1. **Main Script** (`cloud-ignore-files.sh`): Installer/manager that:
   - Detects system architecture and selects appropriate unison binary
   - Copies custom unison binary based on architecture
   - Configures sync paths and ignore patterns
   - Uses template files to generate actual configuration
   - Sets up and manages a launchd service on macOS

2. **Template Files**:
   - `plist.template`: launchd service configuration template
   - `script.template`: Unison sync command template with watch mode
   - `sync-once.template`: Manual sync command template

3. **Generated Files**:
   - `~/.unison/bin/unison-cloud-sync-ignore`: The actual sync script
   - `sync-mirror`: Manual sync command (in PATH)
   - `~/Library/LaunchAgents/com.chrisblossom.projects.CloudSyncIgnore.plist`: launchd service
   - Log files in `~/.unison/`: `cloudsyncignore.unison.log`, `cloudsyncignore.stdout.log`, `cloudsyncignore.stderr.log`

## Configuration Variables

Key variables in `cloud-ignore-files.sh`:

- **`local_path`**: Local working projects directory, defaults to `${HOME}/github`
- **`cloud_path`**: Cloud-synced mirror directory, defaults to `${HOME}/Dropbox/github-mirror`
- **`ignore_files`** array: Files/patterns to exclude from sync using Unison `Name` matching
- **`ignore_regexs`** array: Full-path regex patterns excluded using Unison `Regex` matching

`ignore_files` are joined into a comma-separated string for Unison's `Name {a,b,c}` syntax.

`ignore_regexs` are passed as repeated Unison flags like `-ignore='Regex <pattern>'`.

Example Git-related defaults included:

- `ignore_regexs` includes patterns to ignore Git lock files and pack temp files:
  - `.*/\\.git/.*\\.lock$`
  - `.*/\\.git/objects/pack/(tmp_|\\.tmp-).*`

## Custom Unison Binaries

The project automatically detects your Mac's architecture and uses the appropriate custom unison binary:

- **Apple Silicon**: `unison-silicon`
- **Intel Macs**: `unison-intel`

These custom binaries are copied to your Homebrew bin directory during installation. The key change is temp file naming: `.unison.tmp` becomes `.~unison.temp` so Dropbox ignores them.

See: https://github.com/bcpierce00/unison/pull/447

## Dependencies

- **Custom [`unison`](https://github.com/bcpierce00/unison) binaries**: Included with modified temp file naming for Dropbox compatibility
- **[`unison-fsmonitor`](https://github.com/autozimu/unison-fsmonitor)**: Required for file watching capability
- **macOS with Homebrew**: Currently macOS-specific 
- **Full Disk Access**: For iCloud users, `/bin/bash` needs Full Disk Access permission

## How Syncing Works

1. Uses custom `unison` binary with `-repeat=watch` for continuous monitoring
2. Bidirectional sync between local and cloud directories
3. Prefers newer files on conflict
4. Preserves file permissions and timestamps
5. Ignores specified patterns via `Name` and `Regex` rules (e.g., `node_modules`, Git temp files)
6. Creates temporary files with `.~` prefix to avoid cloud service conflicts

## Testing Changes

When modifying ignore patterns or paths:
1. Edit the variables at the top of `cloud-ignore-files.sh`
2. Run `./cloud-ignore-files.sh --update` to regenerate and reload config
3. Check logs in `~/.unison/` for any sync issues
