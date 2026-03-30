# Architecture

## Overview

Cipher Desk is a local-first Windows desktop application built around a PowerShell + WPF UI.

The project has three main layers:

1. UI layer
2. cryptography layer
3. packaging / launcher layer

## UI Layer

The main application UI lives in `CipherDesk.ps1`.

It uses WPF to provide:

- mode selection for text, image, and document workflows
- action selection for encrypt / decrypt
- local file picking and save dialogs
- image preview for image workflows
- convenience actions for decrypted documents

## Cryptography Layer

The cryptographic flow is implemented directly in `CipherDesk.ps1`.

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

## File Model

Text mode returns JSON directly in the UI.

Image and document modes save the same JSON payload into `.cdesk` files.

The detailed format is documented in `docs/file-format.md`.

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
