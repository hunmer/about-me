# Findings

## Initial
- Investigation started.

## Implementation findings
- `AIAgent.messages` uses `PromptEditor`'s `Prompt` model and is persisted by `AgentController`.
- Agent Chat conversations support groups and messages are persisted through `ConversationController` services.
- `RequestService.chat` provides a complete response for an existing OpenAI Agent.
- Jelly Live2D now accepts an initial model and externally supplied bubble message.
- Existing `Live2DOnlineModelPage` returns a fully loaded `Live2DModelDefinition`; it can be reused directly from plugin settings.
- `Live2DViewController.startMotion` supports explicit group/index and is suitable for reply reactions.
- `AgentListDrawer` is a modal selector with single-selection support; `AgentEditScreen(agent: ...)` edits and persists an existing Agent.
- `AgentListDrawer` supports both default and extra-storage tabs; one search field filters both lists.
- `AgentEditScreen` returns `true` for normal saves, so the drawer detects newly created records by comparing IDs before and after navigation.
- Live2D Agent selection now consumes the typed modal result after dismissal, avoiding parent `setState` during drawer pop.
