# Native Tutoring Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Connect adaptive voice tutoring to native Mac controls and live anchored overlays.

**Architecture:** A native app service retains short-lived Accessibility references behind opaque
control IDs. The existing tool dispatcher calls this service. The overlay controller resolves
anchors locally while a mark is visible. A small learning-context policy uses existing evidence.

**Tech Stack:** Swift 6, macOS 15+, ApplicationServices, AppKit, SwiftUI, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-18-native-tutoring-design.md`

## Global Constraints

- New source files stay below 300 lines; preserve unrelated edits.
- Keep existing OpenAI voice and OpenRouter visual paths.
- No extra dependencies, silent fallbacks, new computer-use model or automatic permission grants.
- Preserve the existing opt-in computer-control setting.

## Review Focus

- A stale control ID must never activate a newly indexed control.
- App/window switches and hidden targets must not leave misleading marks.
- An accepted native action is not proof that a learning goal was achieved.
- Repeated overlay updates must not restart the mark animation or expiry.
- Unaided checks must not silently receive teaching cues.

### Task 1: Native app control service

Files: `ScreenTutor/Native/NativeAppModels.swift`, `NativeAppService.swift`,
`AccessibilityAppBackend.swift`, `AccessibilityElement.swift`, `ScreenTutorTests/NativeAppServiceTests.swift`.

- [ ] Add failing tests for inspection IDs, stale focus, actions and fresh snapshots.
- [ ] Implement a main-actor backend boundary and live Accessibility implementation.
- [ ] Disable App Sandbox for the native desktop target and regenerate the project.
- [ ] Run the focused service tests and inspect build entitlements.

### Task 2: Live anchored overlays

Files: `ScreenTutor/Overlay/OverlayModels.swift`, `OverlayController.swift`,
`LiveOverlayTracking.swift`, `ScreenTutorTests/LiveOverlayTests.swift`.

- [ ] Add failing tests for movement, clipping, missing targets and cleared scenes.
- [ ] Resolve native anchor frames only while marks are visible; retain mark identity and expiry.
- [ ] Reuse panel/view identity while updating geometry; never redraw through a model call.
- [ ] Run tracking and existing overlay tests.

### Task 3: Goal-aware tools and tutoring behavior

Files: `ScreenTutor/Learning/TutorSupportContext.swift`, `ScreenTutor/Realtime/NativeFunctionTools.swift`,
`ScreenTutor/App/AppModel+NativeTools.swift`, existing dispatch/lifecycle/learning handlers,
`ScreenTutorTests/NativeTutorToolsTests.swift`, `TutorSupportContextTests.swift`.

- [ ] Add failing tests for schema registration, adaptive context and unaided checks.
- [ ] Implement inspect, activate and highlight tools plus session learning goals.
- [ ] Return refreshed native state and current teaching guidance in tool results.
- [ ] Prefer native tools in core instructions; clear references on teardown and app exit.
- [ ] Run tool, learning and protocol tests.

### Task 4: Integration and iteration

- [ ] Run a controlled native fixture test when OS permission permits.
- [ ] Run the complete local test suite with live network tests disabled by default.
- [ ] Inspect failures, simplify interactions, and rerun only affected checks.
- [ ] Document tested behavior, native permission requirements and remaining limits.
