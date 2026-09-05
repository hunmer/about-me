# Progress Log

## Session start
- Created planning files.

## Completed
- Added Live2D archive model, plugin persistence, settings screen, model/agent/personality controls.
- Registered plugin and `/live2d` route.
- Added Jelly Home chat input and response bubble integration.
- `dart analyze lib` clean; focused Live2D/Jelly tests passed.
- Added online model picker entry, archive deletion with temporary conversation cleanup, and AI reply reaction motion trigger.
- Optimization validation passed: targeted analyze/tests and `procm-mcp` analyze all exited successfully.
- Replaced settings dropdowns/editor with archive chips, model list sheet, `AgentListDrawer`, and `AgentEditScreen` navigation.
- Added always-visible Agent creation button and name/description search filtering to `AgentListDrawer`.
- New Agent creation now auto-selects the newly created item in the drawer.
- New Agent creation now immediately calls the selection callback and closes the drawer.
- Fixed Agent selection crash risk by applying drawer results after modal dismissal instead of mutating Live2D settings during the drawer callback.

## 2026-09-05 Live2D TTS
- Read the handoff and existing TTS settings/playback flow.
- Confirmed that selecting a configured TTS service is the existing app-level abstraction for selecting a voice.
- One combined read returned exit code 1 without output; switched to direct focused reads.
- Confirmed parallel orchestration aborts when any `rg` returns its normal no-match code; future searches normalize that exit code.
- Added Live2D TTS settings, service selection UI, and final-message playback hook.
- Corrected an incomplete placeholder introduced during the first patch before running formatting or analysis.
