# Changelog

## 0.2.3

- Split the large app file into dedicated modules for core crypto, passwords, files, screenshots, UI helpers, and mode handlers.
- Reduced the size of `CipherDesk.App.ps1` so it focuses on XAML, control wiring, and startup flow.
- Updated README and architecture documentation to describe the new module layout.
- Kept portable packaging aligned with the modular runtime structure.

## 0.2.2

- Moved screenshot automation out of the public entrypoint into a separate internal app layer.
- Simplified `CipherDesk.ps1` so it behaves like a user-facing launcher and self-test wrapper.
- Updated portable packaging to include the split runtime files explicitly.
- Refreshed documentation around dev tooling and screenshot generation.

## 0.2.1

- Fixed demo screenshot text encoding so Russian sample text renders correctly.
- Added built-in password generation with random password, passphrase, copy, length, and character-set options.
- Added automated screenshot capture flow driven by demo assets and scenario definitions.
- Refreshed README and screenshot set for the 0.2.1 release.

## 0.2.0

- Added dark desktop UI with dedicated modes for text, image, and document workflows.
- Added image preview inside the application.
- Added document actions such as `Open file` and `Show in folder`.
- Added portable build flow via `make-portable-release.ps1`.
- Added Russian README and screenshot documentation.
- Added `SECURITY.md`, `LICENSE`, `docs/file-format.md`, and `docs/architecture.md`.
- Removed the old web version and obsolete installer artifacts from the repository.

## 0.1.0

- Initial Windows desktop version of Cipher Desk.
- Added offline encryption for text payloads.
- Added file encryption for images and documents.
- Added launcher executable and portable packaging flow.
