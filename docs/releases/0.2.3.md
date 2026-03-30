# Cipher Desk 0.2.3

## Highlights

- split the application into dedicated PowerShell modules
- reduced the size and responsibility of `CipherDesk.App.ps1`
- updated documentation to explain the new architecture

## Included Improvements

- added separate modules for crypto, passwords, files, screenshots, UI helpers, and mode handlers
- kept the public entrypoint simple for normal users
- kept portable packaging aligned with the modular runtime layout
