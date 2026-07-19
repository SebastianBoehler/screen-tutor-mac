# Custom Tutor Instructions Design

## Goal

Let people adapt ScreenTutor's teaching style from Settings without allowing a customization to remove the screen-capture, privacy, highlighting, or truthfulness contract required by the app's tools.

## Prompt boundary

The Realtime session prompt has two layers:

1. An immutable core owned by the app. It defines screen-tool ordering, prompt-injection handling, capture truthfulness, and teaching-pointer limitations.
2. Editable tutor instructions owned by the user. They describe teaching style, depth, questioning behavior, and domain preferences.

The app places the editable layer in an explicitly delimited section and states that it cannot override the core. The existing pedagogical behavior becomes the default editable value so upgrading users retain today's behavior.

## Settings behavior

- Show a multiline `Tutor instructions` editor in the Tutor section.
- Save only when the user clicks `Save Instructions`.
- Store the value locally in `UserDefaults`; API-key storage remains in Keychain.
- Provide `Restore Default` and disable it when the default is already active.
- Explain that changes apply only to new conversations.
- Keep blank instructions valid: a user may choose to rely only on the immutable core.

## Session behavior

`AppModel` reads the saved instructions when it configures a newly created Realtime session. It does not update a live session, preserving conversation consistency across pause/resume and repeated hotkey invocations.

## Search boundary

This change does not claim or add web grounding. ScreenTutor currently exposes only its three native screen tools. Realtime supports separately configured function or MCP tools, so grounded web search should be designed as an independent capability with its own provider, citations, privacy behavior, error handling, and tool-history presentation.

## Verification

- Unit tests verify default loading, persistence, reset, and prompt composition.
- Protocol tests verify custom instructions appear while immutable screen safety remains present.
- The macOS app and unit-test target build successfully.
