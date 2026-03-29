# Packaging For Direct `logisim-evolution` Launch

This note documents how the repository currently packages the application and what needs to change if the goal is:

1. users download an official package for their platform,
2. installation exposes a `logisim-evolution` command,
3. users can launch the application directly from a terminal.

## Current State

### Linux

Linux packages are created with `jpackage` and explicitly install under `/opt`:

- `createDeb`
- `createRpm`
- shared Linux params include `--install-dir /opt`

This produces an application tree under `/opt/logisim-evolution`, with the launcher typically located at:

```text
/opt/logisim-evolution/bin/logisim-evolution
```

The build also enables `--linux-shortcut`, which provides desktop integration, not shell PATH integration.

Snap already exposes a `logisim-evolution` command through `apps.logisim-evolution.command`.

### Windows

Windows packages are built as MSI installers with:

- Start Menu integration
- desktop shortcut
- installation directory chooser

The current MSI configuration does not add the install directory to `PATH` and does not register an `App Paths` entry. A plain `logisim-evolution` command is therefore not guaranteed to work in `cmd.exe`, PowerShell, or Windows Terminal.

### macOS

macOS packaging currently creates:

1. an `app-image` (`Logisim-evolution.app`)
2. a `dmg` containing that `.app`

The final install location is chosen by the user, usually:

```text
/Applications/Logisim-evolution.app
```

or:

```text
~/Applications/Logisim-evolution.app
```

The actual binary inside the bundle is typically:

```text
/Applications/Logisim-evolution.app/Contents/MacOS/Logisim-evolution
```

That path is not added to shell `PATH`, so a terminal command does not become available automatically.

## Recommended Target Behavior

### Linux

Keep the current `/opt/logisim-evolution` application image for DEB and RPM, but ensure package installation also provides:

```text
/usr/bin/logisim-evolution
```

That launcher should delegate to:

```text
/opt/logisim-evolution/bin/logisim-evolution
```

This is the standard Linux packaging approach and is preferable to editing users' shell profiles or global environment variables.

For Snap, keep the existing command name as-is.

### Windows

Keep MSI packaging, but add one of these installation-time integrations:

1. preferred: register `App Paths\\logisim-evolution.exe`
2. optional: append the install directory to machine or user `PATH`

`App Paths` is usually less invasive than editing `PATH`, but it only helps Windows command resolution for executable launches. If the project specifically wants `logisim-evolution` without a `.exe` suffix in shells, PATH changes are the more universal option.

Because `jpackage` does not provide a built-in switch for this behavior in the current build, this likely requires a custom MSI step or a switch to a more customizable installer toolchain.

### macOS

Do not rely on `.dmg` if terminal launch support is a requirement.

Instead, provide a `.pkg` installer that:

1. installs `Logisim-evolution.app` under `/Applications`
2. installs a wrapper script at `/usr/local/bin/logisim-evolution`

The wrapper script should exec:

```text
/Applications/Logisim-evolution.app/Contents/MacOS/Logisim-evolution
```

This aligns with macOS conventions. `.dmg` is fine for GUI drag-and-drop distribution, but it is not a good vehicle for provisioning command-line entry points.

## Proposed Implementation Plan

### Phase 1: Linux

Goal: make DEB and RPM install a stable command without changing package layout.

Suggested implementation:

1. create Linux packaging resources for post-install integration or package-managed symlink/script installation
2. add `/usr/bin/logisim-evolution` wrapper or symlink target during package build
3. keep Snap unchanged

Desired end state:

```text
logisim-evolution
-> /usr/bin/logisim-evolution
-> /opt/logisim-evolution/bin/logisim-evolution
```

### Phase 2: macOS

Goal: provide an installer package that supports terminal usage.

Suggested implementation:

1. add a new `createPkg` Gradle task
2. use `jpackage --type pkg` instead of only `--type dmg`
3. add installer resources that place a wrapper at `/usr/local/bin/logisim-evolution`
4. keep `createDmg` only as an optional GUI-only artifact

Desired end state:

```text
/Applications/Logisim-evolution.app
/usr/local/bin/logisim-evolution
```

### Phase 3: Windows

Goal: allow terminal launch after MSI installation.

Suggested implementation:

1. decide whether to use `App Paths`, `PATH`, or both
2. if staying on plain `jpackage`, investigate whether an MSI transform or post-processing step is acceptable
3. otherwise move Windows packaging to a more customizable installer definition

Practical recommendation:

- first try `App Paths` if "launch from Win+R and Windows shell resolution" is sufficient
- use `PATH` only if explicit shell-first behavior is required

## Platform Tradeoffs

### Linux

- lowest risk
- closest to current implementation
- should be implemented first

### macOS

- technically clean if switched to `.pkg`
- not compatible with the current drag-and-drop-only installation model

### Windows

- most packaging-tool dependent
- likely needs tooling beyond the current `jpackage` flags

## Recommended Order

1. Linux DEB/RPM: add `/usr/bin/logisim-evolution`
2. macOS: add `.pkg` and `/usr/local/bin/logisim-evolution`
3. Windows: choose between `App Paths` and `PATH`, then adjust the installer pipeline

## Notes For This Repository

This repository already has a reasonable cross-platform packaging baseline:

- Linux: `deb`, `rpm`, `snap`
- Windows: `msi`
- macOS: `app-image`, `dmg`

The missing part is not the application launcher itself. The missing part is installer-time operating-system integration for command discovery.
