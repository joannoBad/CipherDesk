# Cipher Desk

`Cipher Desk` is an offline Windows desktop application for local encryption of text, images, and documents.

The project works fully offline and does not depend on external services.

## Overview

- Version: `0.2.3`
- Platform: `Windows`
- UI: `PowerShell + WPF`
- Cryptography: `AES-256-CBC` + `HMAC-SHA256` + `PBKDF2-SHA256`
- Container format: `.cdesk`

## Features

- encrypt text into `JSON`
- encrypt images into `.cdesk`
- encrypt documents into `.cdesk`
- restore the original file extension during decryption
- preview images in the UI
- open a decrypted document and show it in its folder
- generate a random password directly in the application
- generate a passphrase from multiple words
- copy the current password to the clipboard
- configure password length and character groups
- build a portable release with a dedicated script

## Password Generation

The application includes a built-in password generator below the `Password` field.

Available actions:

- `Generate` for a random password
- `Passphrase` for a multi-word passphrase
- `Copy password` to copy the current value
- length presets: `12`, `16`, `20`, `24`, `32`
- character group toggles: `A-Z`, `a-z`, `0-9`, `!@#`

This makes it easy to create a strong password before encryption without switching to another tool.

## Quick Start

Run the application with one of these entry points:

- `CipherDeskLauncher.exe`
- `Launch-CipherDesk.cmd`
- `CipherDesk.ps1`

## Build A Portable Release

Quick launch:

```cmd
make-portable-release.cmd
```

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1
```

With a custom output folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-portable-release.ps1 -OutputRoot .\release
```

## Verify An Official Release

For public release artifacts you can generate an archive and checksum file:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-checksums.ps1
```

The script creates:

- a `.zip` archive for the current portable build
- `SHA256SUMS.txt` with `SHA-256` hashes for the archive and `CipherDeskLauncher.exe`

Verify a file on Windows:

```powershell
Get-FileHash .\CipherDesk-Portable-30-03-2026-0.2.3.zip -Algorithm SHA256
```

Recommended workflow:

- download releases only from this repository's GitHub Releases page
- compare the downloaded archive hash with `SHA256SUMS.txt`

## Testing

Basic self-test:

```powershell
powershell -ExecutionPolicy Bypass -File .\CipherDesk.ps1 -SelfTest
```

Dedicated roundtrip test:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\test-roundtrip.ps1
```

Expected result:

```text
Self-test OK
```

## Documentation

- [SECURITY.md](SECURITY.md) - limitations, threat model, and guidance
- [CHANGELOG.md](CHANGELOG.md) - change history
- [docs/file-format.md](docs/file-format.md) - `.cdesk` format description
- [docs/architecture.md](docs/architecture.md) - application architecture
- [docs/releases/0.2.3.md](docs/releases/0.2.3.md) - notes for version `0.2.3`
- [demo-assets/README.md](demo-assets/README.md) - demo files for automated screenshot refresh

## Refresh Screenshots

The script can automatically recreate all README screenshots from files stored in `demo-assets`.
Absolute local disk paths are redacted during post-processing so that only project-relative folders remain visible on the final images.

```powershell
powershell -ExecutionPolicy Bypass -File .\make-screenshots.ps1
```

Scenario definitions are stored in [screenshot-scenarios.json](screenshot-scenarios.json), while demo inputs and generated artifacts live in [demo-assets](demo-assets/README.md).

## Screenshots

Text encryption:

![Text encryption](docs/screenshots/text-encrypt.png)

Text decryption:

![Text decryption](docs/screenshots/text-decrypt.png)

Image encryption:

![Image encryption](docs/screenshots/image-encrypt.png)

Image decryption:

![Image decryption](docs/screenshots/image-decrypt.png)

Image file selection and preparation:

![Image workflow](docs/screenshots/image-workflow.png)

Document encryption:

![Document encryption](docs/screenshots/document-encrypt.png)

Document decryption:

![Document decryption](docs/screenshots/document-decrypt.png)

Working with a decrypted document:

![Document workflow](docs/screenshots/document-workflow.png)

Decryption error:

![Decryption error](docs/screenshots/decrypt-error.png)

## Repository Structure

- `CipherDesk.ps1` - main desktop entry point
- `CipherDesk.App.ps1` - internal window implementation and orchestration layer
- `CipherDeskLauncher.cs` - launcher source
- `CipherDeskLauncher.exe` - launcher for running the app like a regular program
- `Launch-CipherDesk.cmd` - simple local launcher
- `make-portable-release.ps1` - full portable build script
- `make-portable-release.cmd` - quick build entry point
- `make-screenshots.ps1` - automated screenshot refresh
- `screenshot-scenarios.json` - scenario list for screenshot automation
- `modules/` - functional application modules
- `tests/test-roundtrip.ps1` - roundtrip test scenario
- `docs/file-format.md` - container format notes
- `docs/architecture.md` - short project architecture overview

## Dev Tooling

The internal logic for automated screenshots is kept out of the public user entry point and separated into a dedicated internal layer:

- [CipherDesk.ps1](CipherDesk.ps1) - normal user launch and self-test
- [CipherDesk.App.ps1](CipherDesk.App.ps1) - internal UI implementation and orchestration
- [make-screenshots.ps1](make-screenshots.ps1) - orchestration for refreshing README screenshots

This keeps the main entry point straightforward for users while dev-oriented scenarios stay separate from everyday application startup.

## Modular Structure

The project is split into dedicated modules by responsibility:

- [CipherDesk.Core.ps1](modules/CipherDesk.Core.ps1) - cryptography, payload handling, text helpers, and self-test
- [CipherDesk.Passwords.ps1](modules/CipherDesk.Passwords.ps1) - random password and passphrase generation
- [CipherDesk.Files.ps1](modules/CipherDesk.Files.ps1) - file dialogs and path helpers for `.cdesk` and restored files
- [CipherDesk.Screenshots.ps1](modules/CipherDesk.Screenshots.ps1) - internal screenshot automation support
- [CipherDesk.UiHelpers.ps1](modules/CipherDesk.UiHelpers.ps1) - status, preview, file info, and UI helper functions
- [CipherDesk.ModeHandlers.ps1](modules/CipherDesk.ModeHandlers.ps1) - mode switching, run action, and runtime mode behavior

This keeps the app easier to read, maintain, and refactor as the project grows.
