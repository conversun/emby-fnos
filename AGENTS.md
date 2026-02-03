# AGENTS.md - Emby Server fnOS Package

## Project Overview

This repository builds fnOS application packages (`.fpk`) for Emby Media Server.
The build process downloads official Emby releases, repackages them for fnOS (飞牛私有云),
and publishes via GitHub Actions.

**Platform**: fnOS (飞牛私有云 NAS system)
**Architecture**: x86_64 (amd64) only
**Language**: Shell scripts (Bash/POSIX sh)

---

## Build Commands

### Local Build (Manual)
```bash
./update_emby.sh              # Build latest stable version
./update_emby.sh 4.9.3.0      # Build specific version
./update_emby.sh beta         # Build latest beta
./update_emby.sh --help       # Show help
```

### Build Requirements
- `curl` - HTTP client for downloads
- `ar` - Archive tool for .deb extraction
- `tar` - Tarball creation
- `sed` - Stream editing for manifest updates
- `md5sum` or `md5` - Checksum calculation

### Build Output
- `embyserver_X.X.X.X.fpk` - Final fnOS package (tarball of package/)
- `package/app.tgz` - Application files (Emby server binaries + config)
- `package/manifest` - Package metadata with version and checksum

### CI/CD
GitHub Actions runs daily at UTC 8:00 (Beijing 16:00):
- Checks for new Emby releases
- Builds and publishes `.fpk` to GitHub Releases
- Manual trigger available via `workflow_dispatch`

---

## Directory Structure

```
emby-fnos/
├── update_emby.sh          # Main build script (local dev)
├── fnos/                   # fnOS package template
│   ├── manifest            # Package metadata (version, checksum)
│   ├── EmbyServer.sc       # Port forwarding config
│   ├── ICON*.PNG           # App icons
│   ├── bin/
│   │   └── emby-server     # Service launcher script
│   ├── cmd/                # Lifecycle scripts
│   │   ├── common          # Shared functions library
│   │   ├── main            # Service start/stop/status
│   │   ├── installer       # Installation orchestrator
│   │   ├── service-setup   # Service configuration
│   │   ├── install_*       # Install hooks
│   │   ├── uninstall_*     # Uninstall hooks
│   │   └── upgrade_*       # Upgrade hooks
│   ├── config/
│   │   ├── privilege       # User/group permissions (JSON)
│   │   └── resource        # Port/share config (JSON)
│   ├── ui/
│   │   ├── config          # Desktop app entry (JSON)
│   │   └── images/         # UI icons (16-256px)
│   └── wizard/
│       └── uninstall       # Uninstall wizard UI (JSON)
└── .github/workflows/
    └── build.yml           # CI/CD pipeline
```

---

## Code Style Guidelines

### Shell Scripts

**Shebang**:
- Use `#!/bin/bash` for scripts requiring bash features
- Use `#!/bin/sh` for POSIX-compatible scripts (bin/emby-server)

**Error Handling**:
```bash
set -e                      # Exit on error (use in main scripts)
command || error "message"  # Explicit error handling
```

**Logging Functions** (defined in update_emby.sh):
```bash
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
```

**Variable Naming**:
- UPPERCASE for constants and environment vars: `EMBY_VERSION`, `APP_DIR`
- UPPERCASE for fnOS system vars: `TRIM_APPNAME`, `TRIM_PKGVAR`, `TRIM_APPDEST`
- Quote variables: `"$variable"` (especially paths)

**Path Constants** (fnOS conventions):
```bash
APP_DIR=/var/apps/embyserver/target    # Installed app location
APP_DATA_DIR=/var/apps/embyserver/var  # Runtime data
PID_FILE="${APP_DATA_DIR}/${APP_NAME}.pid"
LOG_FILE="${TRIM_PKGVAR}/${TRIM_APPNAME}.log"
```

**Command Shortcuts** (from fnos/cmd/common):
```bash
MV="/bin/mv -f"
RM="/bin/rm -rf"
CP="/bin/cp -rfp"
MKDIR="/bin/mkdir -p"
LN="/bin/ln -nsf"
RSYNC="/bin/rsync -avh"
```

### JSON Configuration Files

**Formatting**: 4-space indentation, lowercase keys with hyphens, no trailing commas

**Examples**:
```json
// config/privilege - User permissions
{
    "defaults": {"run-as": "root"},
    "username": "EmbyServer",
    "groupname": "EmbyServer",
    "join-groups": ["video","render"]
}

// config/resource - Resources
{
    "port-config": {"protocol-file": "EmbyServer.sc"},
    "data-share": {"shares": [{"name": "EmbyServer", "permission": {"rw": ["EmbyServer"]}}]}
}
```

### Manifest Format

INI-style with fixed-width alignment:
```ini
appname         = embyserver
version         = 4.9.3.0
display_name    = Emby
maintainer      = Emby LLC
checksum        = <md5sum of app.tgz>
```

---

## Testing & Verification

### Local Testing
```bash
./update_emby.sh 4.9.3.0
tar -tzf embyserver_4.9.3.0.fpk | head -20   # Verify package structure
grep "^version" package/manifest              # Check manifest version
grep "^checksum" package/manifest             # Check manifest checksum
```

### Shell Script Linting
```bash
shellcheck update_emby.sh
shellcheck fnos/bin/emby-server
shellcheck fnos/cmd/*
```

### JSON Validation
```bash
python3 -m json.tool fnos/config/privilege
python3 -m json.tool fnos/config/resource
python3 -m json.tool fnos/ui/config
```

---

## Common Mistakes to Avoid

1. **Don't forget `set -e`** in main scripts for early failure
2. **Always quote paths**: `"$WORK_DIR"` not `$WORK_DIR`
3. **Use proper cleanup**: trap on EXIT for temp directories
4. **Match manifest format**: fixed-width columns with spaces around `=`
5. **Keep POSIX compat** in bin/emby-server (no bash-isms)
6. **Validate JSON** before committing config changes
7. **Test extraction**: `tar -tzf file.fpk` to verify package structure
