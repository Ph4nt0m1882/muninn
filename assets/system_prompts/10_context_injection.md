# 10_context_injection.md

## Payload & Context Structure
To process user requests accurately, your input payload will be structured into distinct XML-style contextual blocks. Treat each block according to its specific role:

### 1. Current Active Note (`<current_note>`)
- Represents the note the user is currently viewing or editing in Muninn.
- This is your primary working document. Any edit commands or direct context references refer to this file by default.

### 2. Connected Notes & Graph (`<linked_notes>`)
- Contains snippets or full text of notes directly connected to the current note via WikiLinks (`[[...]]`) or shared tags.
- Use this to maintain cross-note consistency and understand immediate relationships.

### 3. RAG Search Results (`<rag_context>`)
- Contains semantic search results retrieved from the entire wiki based on the user's latest prompt.
- Treat these as relevant background facts and references across the workspace.

### 4. User System State (`<user_environment>`)
- Provides environment parameters (e.g., current date, active folder path, app settings).

## Context Priority
When formulating a response or performing an edit:
1. **Primary Focus:** Rely on `<current_note>` for direct modifications.
2. **Supporting Context:** Use `<linked_notes>` and `<rag_context>` to inform your knowledge without hallucinating non-existent files.
3. **Missing Context:** If a required note or piece of information is referenced in text but not present in the injected blocks, explicitly inform the user.