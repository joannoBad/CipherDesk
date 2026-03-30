# Cipher Desk 0.2.2

## Highlights

- moved screenshot automation out of the public entrypoint
- split the runtime into a clean launcher script and an internal app implementation
- kept portable packaging aligned with the new structure

## Included Improvements

- `CipherDesk.ps1` now acts as a simple user-facing wrapper
- `CipherDesk.App.ps1` holds the UI implementation and dev automation hooks
- documentation now explains the separation between user runtime and dev tooling
