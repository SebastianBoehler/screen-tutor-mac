# Security Policy

## Supported version

ScreenTutor is currently an early-stage project without stable releases. Security fixes target the latest commit on `main`.

## Report a vulnerability

Please do not open a public issue for a suspected vulnerability.

Use **Security → Report a vulnerability** on this GitHub repository to submit a private report. Include:

- the affected version or commit;
- the operating system, browser or Xcode versions;
- reproduction steps and expected impact;
- relevant logs with API keys, voice data, screenshots, and personal information removed; and
- a suggested remediation, if you have one.

The maintainer will assess the report, coordinate a fix when appropriate, and credit reporters who want attribution. Normal bugs that do not have security or privacy impact belong in the public issue tracker.

## Credential exposure

Never include an OpenAI API key in an issue, pull request, screenshot, or log. If a key may have been exposed, revoke it with the provider immediately; removing it from a later commit does not remove it from Git history.

## Local web client boundaries

The solo web API binds to loopback and uses fixed provider URLs. It rejects foreign hostnames,
foreign origins and mutation requests without the client header. This is not authentication for
remote hosting. Do not expose this server through a public tunnel or shared network interface.

Client-entered keys stay in tab memory and transit the local server for provider calls. Server
environment keys remain on the server. Neither is written to the learning workspace. Browser
learning data is not application-encrypted. Relevant excerpts and conversation are sent to the
chosen provider; camera frames are sent only after explicit sharing. The rich renderer sanitizes
HTML, disables trusted math commands and exposes no native/OS bridge.

Report source injection, script execution, cross-origin access, credential leakage or incorrect
assistance attribution as security or integrity issues. Remove private study data from reports.
