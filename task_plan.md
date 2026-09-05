# Live2D Plugin Implementation Plan

## Goal
Create a Live2D plugin with archive settings, prompt editor integration, Jelly Home chat input, Live2D bubble replies, and AI Chat-compatible persistence/channel grouping.

## Phases
- [completed] Inspect existing plugin, routing, Live2D, prompt editor, and AI chat patterns
- [completed] Design and implement Live2D archive model/service and plugin settings UI
- [completed] Integrate Jelly Home chat input and Live2D bubble response flow
- [completed] Wire registration, persistence, and fixed channel grouping
- [completed] Run focused analysis/tests and fix issues
- [completed] Add online model selection, archive deletion, and reaction motions
- [completed] Validate optimization changes
- [completed] Replace Live2D selects with drawer/list interactions and Agent Editor navigation
- [completed] Validate interaction refactor
- [completed] Add AgentListDrawer creation action and search filtering
- [completed] Auto-select newly created Agent after editor returns
- [completed] Auto-close drawer and return newly selected Agent
- [in_progress] Add Live2D auto-read setting and TTS service selection
- [pending] Trigger TTS once when a Live2D AI reply completes
- [pending] Run focused analysis and tests for Live2D TTS integration

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Parallel focused read returned exit code 1 without output | 1 | Split into direct reads; likely an `rg` no-match exit code rather than a code failure. |
| Parallel read again aborted on an `rg` no-match exit code | 2 | Stop grouping fallible searches; append `if ($LASTEXITCODE -eq 1) { exit 0 }` for no-match searches. |
| First business patch left an incomplete `Marker` placeholder in the TTS loader | 1 | Immediately replaced it with the complete service lookup and settings methods before validation. |
