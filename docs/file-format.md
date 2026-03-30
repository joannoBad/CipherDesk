# Cipher Desk File Format

This document describes the current encrypted payload format used by Cipher Desk.

## Overview

Cipher Desk stores encrypted payloads as JSON.

For text mode, the JSON is shown directly in the app.

For image and document modes, the same JSON payload is saved to a file with the `.cdesk` extension.

## Top-Level Fields

Example structure:

```json
{
  "version": 1,
  "algorithm": "AES-256-CBC",
  "integrity": "HMAC-SHA256",
  "kdf": "PBKDF2-SHA256",
  "payloadType": "document",
  "originalName": "contract.pdf",
  "originalExtension": ".pdf",
  "iterations": 250000,
  "salt": "...base64...",
  "iv": "...base64...",
  "data": "...base64...",
  "mac": "...base64..."
}
```

## Field Meanings

- `version`: format version, currently `1`
- `algorithm`: content encryption algorithm, currently `AES-256-CBC`
- `integrity`: integrity check algorithm, currently `HMAC-SHA256`
- `kdf`: password-based key derivation function, currently `PBKDF2-SHA256`
- `payloadType`: one of `text`, `image`, or `document`
- `originalName`: original filename when the payload comes from a file
- `originalExtension`: original file extension such as `.png` or `.pdf`
- `iterations`: PBKDF2 iteration count, currently `250000`
- `salt`: random salt in Base64
- `iv`: initialization vector in Base64
- `data`: encrypted payload bytes in Base64
- `mac`: HMAC of `iv + ciphertext`, encoded in Base64

## Notes

- The password is never stored inside the payload.
- Decryption requires the original password.
- If `mac` validation fails, the payload is considered invalid or tampered with.
- The format is designed for app interoperability, not for hiding the implementation details.
