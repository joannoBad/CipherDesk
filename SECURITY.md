# Security Notes

## Scope

Cipher Desk is an offline Windows desktop encryption utility for text, images, and documents.

The project is intended for educational, personal, and small-scale practical use. It is not a formally audited security product.

## What The App Does

- encrypts data locally on the user's machine
- derives keys from a password with `PBKDF2-SHA256`
- encrypts content with `AES-256-CBC`
- protects integrity with `HMAC-SHA256`
- stores encrypted file payloads in a `.cdesk` container

## Important Limitations

- The project has not undergone an external cryptography audit.
- Security depends heavily on the strength of the user's password.
- If an attacker knows the password, the encrypted data can be decrypted.
- The source code is public by design; secrecy does not rely on hiding the algorithm.
- Windows may still keep normal system traces such as recent files, shell history, or file metadata.

## Threat Model

Cipher Desk is designed to protect saved content against casual access and offline inspection when the attacker does not know the password.

It is not designed as a hardened solution against:

- malware already running on the machine
- keyloggers
- memory inspection during active use
- highly targeted forensic workflows
- enterprise or regulated high-assurance environments

## Operational Advice

- Use long, unique passwords or passphrases.
- Do not reuse the same password across unrelated encrypted archives.
- Keep backups of important encrypted files.
- Test decryption before deleting the original source data.
- Treat decrypted output files as sensitive data once restored to disk.

## Responsible Disclosure

If you discover a security issue, please report it privately to the repository owner before opening a public issue.
