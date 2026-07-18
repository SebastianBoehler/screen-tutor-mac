# Contributing to ScreenTutor

Thanks for helping make screen-aware tutoring more useful, private, and accessible.

## Before you start

- Search existing issues before opening a new one.
- Use a bug report for reproducible incorrect behavior and a feature request for a concrete user need.
- Open an issue before a large architectural change so the direction can be discussed first.
- Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Local setup

You need macOS 15 or newer, Xcode 16.4 or newer, and an OpenAI API key with Realtime access. XcodeGen is only needed when source files move or the project configuration changes.

```bash
brew install xcodegen
xcodegen generate
open ScreenTutor.xcodeproj
```

Select your own development team in Xcode. Never commit API keys, signing identities, provisioning profiles, captured screens, or personal test data.

## Make a focused change

1. Fork the repository and create a descriptive branch.
2. Keep the diff scoped to one problem.
3. Match the existing Swift 6 concurrency and directory structure.
4. Prefer small, single-purpose types; keep source files below roughly 300 lines.
5. Add or update focused tests when behavior changes.
6. Use a conventional commit such as `fix: handle interrupted playback` or `feat(ui): improve highlight contrast`.

ScreenTutor deliberately highlights without clicking or typing. Changes that add computer control, broaden capture beyond the active-window turn, or change credential handling need prior design discussion and a clear safety model.

## Validate

Regenerate the Xcode project when required, then run:

```bash
xcodebuild \
  -project ScreenTutor.xcodeproj \
  -scheme ScreenTutor \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Also exercise the affected interaction on a real Mac when the change touches microphone input, playback, ScreenCaptureKit, permissions, the global shortcut, or overlays. Automated tests cannot grant or faithfully simulate those system permissions.

## Open a pull request

Explain the user-visible behavior, why the change is needed, and exactly how you validated it. Include screenshots only when they contain no private information. Keep unrelated cleanup out of the pull request.

By contributing, you agree that your contribution is licensed under the repository's [MIT License](LICENSE).
