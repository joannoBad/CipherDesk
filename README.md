# Cipher Desk

Cipher Desk is a Windows desktop app for local encryption.

It works offline and supports:

- text
- images
- documents

## Features

- local encryption with `AES-256-CBC`
- integrity protection with `HMAC-SHA256`
- password-based key derivation with `PBKDF2-SHA256`
- text encryption to JSON
- image encryption to `.cdesk`
- document encryption to `.cdesk`
- image preview inside the app
- document actions like `Open file` and `Show in folder`

## Run

Start the app with one of these files:

- `CipherDeskLauncher.exe`
- `Launch-CipherDesk.cmd`
- `CipherDesk.ps1`

## Portable Build

Build the current portable release with:

```cmd
make-portable-release.cmd
```

Or run the PowerShell build directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1
```

Or pass the output folder explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1 -OutputRoot .\release
```

## Self-Test

Run the built-in cryptography check with:

```powershell
powershell -ExecutionPolicy Bypass -File .\CipherDesk.ps1 -SelfTest
```

Expected result:

```text
Self-test OK
```

## Repository Layout

- `CipherDesk.ps1` - main desktop app
- `CipherDeskLauncher.cs` - launcher source
- `CipherDeskLauncher.exe` - launcher binary
- `Launch-CipherDesk.cmd` - simple local launcher
- `make-portable-release.ps1` - full portable build script
- `make-portable-release.cmd` - helper launcher for the build script
