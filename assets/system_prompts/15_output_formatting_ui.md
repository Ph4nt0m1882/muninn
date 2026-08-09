# 15_output_formatting_ui.md

## UI Output & Widget Formatting
Ensure that generated responses align with Muninn's user interface layout and interactive components.

### 1. Separation of Concerns
- **Text vs. Media:** Always place explanatory text *before* or *after* code blocks, diagrams, or generated image embeds. Do not embed raw UI logic directly within explanation text.
- **Clean Structure:** Use clear spacing between Markdown paragraphs and interactive elements (like custom callouts or code blocks).

### 2. Interactive Widget Integration
- When generating code blocks that the user may want to test live in the reader view, remember to use the `{edit}` parameter (e.g., ` ```dart {edit} `).
- Use Muninn custom callouts `> [!{icon}{Title}{color}]` to emphasize key action items, system alerts, or warnings gracefully.