# Architecture

## Overview

Cipher Desk is a local-first Windows desktop application built around a PowerShell + WPF UI.

The project is split into several layers:

1. UI layer
2. cryptography layer
3. runtime / mode orchestration layer
4. screenshot automation layer
5. packaging / launcher layer

## UI Layer

The public entrypoint is `CipherDesk.ps1`, but the actual window implementation lives in `CipherDesk.App.ps1`.

The UI-related code is split further:

- `CipherDesk.App.ps1`
  - WPF XAML
  - control lookup
  - event wiring
  - startup flow
- `modules/CipherDesk.UiHelpers.ps1`
  - status text
  - preview helpers
  - file info formatting
  - visual toggle helpers

The WPF UI provides:
- mode selection for text, image, and document workflows
- action selection for encrypt / decrypt
- local file picking and save dialogs
- image preview for image workflows
- convenience actions for decrypted documents

## Cryptography Layer

The cryptographic flow now lives in `modules/CipherDesk.Core.ps1`.

Current design:

- password -> `PBKDF2-SHA256`
- content encryption -> `AES-256-CBC`
- integrity protection -> `HMAC-SHA256`

Encrypted payloads store metadata such as:

- payload type
- original filename
- original extension
- iteration count
- salt
- IV
- ciphertext
- MAC

Self-test coverage also lives in the core layer via `Invoke-CipherDeskSelfTest`.

## Password Layer

Password generation is isolated in `modules/CipherDesk.Passwords.ps1`.

This module contains:

- random password generation
- passphrase generation
- random index helpers used by the generator

Keeping this separate makes the generator easier to evolve without touching encryption or UI code.

## File Model

Text mode returns JSON directly in the UI.

Image and document modes save the same JSON payload into `.cdesk` files.

The detailed format is documented in `docs/file-format.md`.

File-specific helpers are grouped in `modules/CipherDesk.Files.ps1`:

- input file dialogs
- output file dialogs
- encrypted path generation
- restored path generation

Image and document workflows intentionally share this layer because they reuse the same `.cdesk` container logic.

## Runtime / Mode Layer

Mode switching and operational behavior are grouped in `modules/CipherDesk.ModeHandlers.ps1`.

This layer is responsible for:

- current mode resolution
- switching between text / image / document modes
- switching between encrypt / decrypt actions
- executing the main run action for each workflow
- keeping the visible UI state in sync with the selected mode

This separation keeps `CipherDesk.App.ps1` from becoming a single large file with both markup and workflow logic mixed together.

## Screenshot Automation Layer

Automatic README screenshot generation is isolated in `modules/CipherDesk.Screenshots.ps1`.

This layer contains:

- screenshot rendering from the WPF window
- scenario preparation for demo assets

The orchestration script `make-screenshots.ps1` drives those scenarios using files from `demo-assets`.

This is intentionally kept outside the public entrypoint so normal users are not exposed to internal tooling concerns.

## Launcher Layer

The launcher source is `CipherDeskLauncher.cs`.

Its responsibility is minimal:

- locate `CipherDesk.ps1`
- start PowerShell in STA mode
- show an error dialog if the script is missing or fails to start

## Build / Release Flow

Portable build flow is handled by:

- `make-portable-release.ps1`
- `make-portable-release.cmd`

The build script:

- rebuilds the launcher executable
- runs the self-test
- creates a portable release folder
- copies `CipherDesk.ps1`, `CipherDesk.App.ps1`, and the `modules/` folder

## Testing

The project currently uses:

- built-in self-test mode via `CipherDesk.ps1 -SelfTest`
- wrapper test script in `tests/test-roundtrip.ps1`

Current test scope covers:

- text roundtrip
- image roundtrip
- document roundtrip
- wrong password failure
- tampered payload failure
