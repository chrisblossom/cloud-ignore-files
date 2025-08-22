## Project Overview

This is a bidirectional sync utility that enables cloud sync services (like Dropbox, iCloud) to selectively ignore certain project files (like `node_modules`, `target`, etc.) while still syncing the rest of the project. It uses `unison` for bidirectional synchronization between a local working directory and a cloud-synced mirror.

## Key Commands

- **Install/Setup**: `./cloud-ignore-files.sh --install`
- **Update Configuration**: `./cloud-ignore-files.sh --update` (use after modifying the script)
- **Uninstall**: `./cloud-ignore-files.sh --uninstall`

## Architecture

The system consists of:

1. **Main Script** (`cloud-ignore-files.sh`): Installer/manager that:
   - Configures sync paths and ignore patterns
   - Uses template files to generate actual configuration
   - Sets up and manages a launchd service on macOS

2. **Template Files**:
   - `plist.template`: launchd service configuration template
   - `script.template`: Unison sync command template with watch mode

3. **Generated Files** (created in `~/.unison/`):
   - `bin/unison-cloud-sync-ignore`: The actual sync script
   - `~/Library/LaunchAgents/com.chrisblossom.projects.CloudSyncIgnore.plist`: launchd service
   - Log files: `cloudsyncignore.unison.log`, `cloudsyncignore.stdout.log`, `cloudsyncignore.stderr.log`

## Configuration Variables

Key variables in `cloud-ignore-files.sh`:

- **`local_path`**: Local working projects directory (default: `${HOME}/github`)
- **`cloud_path`**: Cloud-synced mirror directory (default: `${HOME}/Dropbox/github-mirror`)
- **`ignore_files`** array: Files/patterns to exclude from sync (node_modules, target, .DS_Store, etc.)

The ignore patterns are joined into a comma-separated string for Unison's `Name {a,b,c}` syntax.

## Dependencies

- **[`unison`](https://github.com/bcpierce00/unison)**: File synchronization tool (install with `brew install unison`)
- **[`unison-fsmonitor`](https://github.com/autozimu/unison-fsmonitor)**: Required for file watching capability (install with `brew install autozimu/homebrew-formulas/unison-fsmonitor`)
- **macOS with Homebrew**: Currently macOS-specific due to `launchctl` usage
- **Full Disk Access**: For iCloud users, `/bin/bash` needs Full Disk Access permission

## How Syncing Works

1. Uses `unison` with `-repeat=watch` for continuous monitoring
2. Bidirectional sync between local and cloud directories
3. Prefers newer files on conflict (`-prefer=newer`)
4. Preserves file permissions and timestamps
5. Ignores specified patterns (node_modules, build artifacts, etc.)

## Testing Changes

When modifying ignore patterns or paths:
1. Edit the variables at the top of `cloud-ignore-files.sh`
2. Run `./cloud-ignore-files.sh --update` to regenerate and reload config
3. Check logs in `~/.unison/` for any sync issues
