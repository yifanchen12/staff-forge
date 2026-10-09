# Security Policy

[English](SECURITY.md) · [简体中文](SECURITY.zh-CN.md)

## Supported versions

Security fixes target the latest published release and the main branch. At publication, the supported release is **0.3.x**. Older releases should be upgraded; a dedicated backport schedule is not maintained.

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/yifanchen12/staff-forge/security/advisories/new) (Security → Report a vulnerability). If the private report control is unavailable, open an issue requesting a private contact channel **without disclosing the vulnerability or an exploit**.

Include the affected version or commit, operating system and Godot version, expected and actual behavior, impact, and minimal reproduction steps or a sanitized sample. Share exploit details and sensitive attachments only in the private report. Do not attach real access tokens, passwords, private keys, personal save files, or unredacted logs.

Reports are reviewed on a best-effort basis. There is no guaranteed response time or paid bounty program. Please coordinate public disclosure with the maintainer so a fix or mitigation can be made available.

## Scope

Relevant issues include unintended file access or code execution, unsafe handling of save data or downloaded archives, accidental credential exposure, and unsafe build or packaging behavior. Report upstream engine vulnerabilities through [Godot's security process](https://github.com/godotengine/godot/security/policy); mention this project if its configuration or bundled version is affected.

Gameplay balance, ordinary rendering bugs and feature requests belong in public issues after removing personal information.

## Safe use and contributions

- The game is local and offline; it does not require account credentials or provide a multiplayer service.
- Build and asset-fetch scripts access external sources. Review script changes before running them. Use official Godot downloads and the documented asset sources.
- Do not run arbitrary untrusted projects or scripts. Do not disable operating-system protections to run an unfamiliar executable.
- Never commit credentials, .env files, export credentials, private signing keys, player saves or local machine settings. The repository ignore rules are a precaution, not a complete secret detector.
- If a credential is exposed, revoke or rotate it promptly. Deleting the latest file alone does not remove it from Git history.
- Test only on systems and files you own or have explicit permission to assess. Do not publish other people's data in a report.

The current checks cover save validation, backup recovery and transaction rollback; they are not a comprehensive security audit. GitHub reporting guidance: [privately reporting a vulnerability](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately).
