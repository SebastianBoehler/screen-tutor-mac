# Native tutoring and live overlays

The learner talks to the existing OpenAI voice tutor while studying in their own Mac apps.
Native tools inspect a focused app window and activate specific Accessibility controls.
Teaching overlays attach to the actual control rather than screenshot coordinates. OpenRouter
remains available for visual material that Accessibility does not expose.

## Behavior

- Record a session learning goal tied to an existing topic and subskill. Derive the next teaching
  move from recorded evidence and the active task. No learning-style questionnaire.
- Read app controls locally. Return opaque IDs, labels, roles and the actions macOS exposes.
- Activate only a control from the latest inspection, with computer control enabled. Reject
  changed apps/windows, disabled controls, unsupported actions and inaccessible targets.
- Return a fresh inspection after an action. Report action dispatch separately from achievement
  of the learner's goal.
- Draw a focused native highlight without a model request. Track its real Accessibility frame
  while the window moves or content scrolls. Hide targets that disappear or leave the foreground.
- During unaided checks, permit navigation but withhold teaching hints until the task is closed
  as assisted. Fade support as the learner demonstrates independent recall.
- Clear marks and native references when the conversation ends. Do not retain app text in a
  separate background log, continuously capture screenshots, or add a computer-use model.

## Implementation boundaries

Swift 6, macOS 15+, existing AppModel tool dispatch, AppKit/SwiftUI overlays, ApplicationServices.
New source files stay below 300 lines. The local desktop build is unsandboxed because App Sandbox
does not support cross-app Accessibility control; explicit macOS Accessibility permission remains.
Secure fields are excluded. Native actions are opt-in under the existing computer-control setting.

## Success checks

Tests cover stale IDs, changed focus, unsupported actions, fresh post-action state, target movement,
disappearance/reappearance, clipping, expiry and cancellation. Adaptive behavior tests cover new
goals, incorrect attempts, assisted practice, independent evidence and unaided checks. Tool-contract
tests verify these features reach the voice session. Run a native fixture test if Accessibility
permission is available; distinguish skipped OS integration from passing isolated checks.
