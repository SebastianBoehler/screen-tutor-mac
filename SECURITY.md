# Security Policy

## Supported version

ScreenTutor is currently an early-stage project without stable releases. Security fixes target the latest commit on `main`.

## Report a vulnerability

Please do not open a public issue for a suspected vulnerability.

Use **Security → Report a vulnerability** on this GitHub repository to submit a private report. Include:

- the affected version or commit;
- the macOS and Xcode versions;
- reproduction steps and expected impact;
- relevant logs with API keys, voice data, screenshots, and personal information removed; and
- a suggested remediation, if you have one.

The maintainer will assess the report, coordinate a fix when appropriate, and credit reporters who want attribution. Normal bugs that do not have security or privacy impact belong in the public issue tracker.

## Credential exposure

Never include an OpenAI API key in an issue, pull request, screenshot, or log. If a key may have been exposed, revoke it with the provider immediately; removing it from a later commit does not remove it from Git history.
