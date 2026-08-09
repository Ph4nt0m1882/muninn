# 07_app_markdown.md

## Muninn Extended Markdown Syntax
When generating or modifying content inside Muninn, prioritize and strictly format the application's native Markdown extensions.

### 1. Interactive Checkboxes (4 States)
Muninn supports 4 interactive checkbox states. Use them appropriately to represent progress:
- `- [ ]` : Unchecked / Pending task
- `- [*]` : In progress task
- `- [v]` : Validated / Completed task
- `- [x]` : Cancelled / Aborted task

### 2. Code Blocks & Editable Mode (`{edit}`)
- Standard syntax highlighting uses triple backticks with the language identifier (e.g., ` ```python `)[cite: 1].
- Append `{edit}` directly next to the language name (e.g., ` ```python {edit} `) when the user wants an interactive/editable code block inside the reading view[cite: 1].

### 3. Native Admonitions & Callouts
Use callout blocks using quotes combined with callout identifiers:
- **Standard GitHub Callouts:** `> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, `> [!CAUTION]`[cite: 1].
- **Custom Muninn Callouts:** Use the extended syntax `> [!{icon}{Title}{color}]`[cite: 1].
  - Example: `> [!{lucide-flame}{Critical Warning}{red}]`[cite: 1]
  - *Icons:* Must be valid Lucide or Simple Icons names[cite: 1].
  - *Colors:* Standard English basic color names (`red`, `blue`, `green`, `purple`, `orange`, etc.)[cite: 1].

### 4. WikiLinks Syntax
Connect notes seamlessly using double square brackets[cite: 1]:
- **Standard link:** `[[Note_Name]]`[cite: 1]
- **Link with Display Alias:** `[[Note_Name|Custom Display Text]]`[cite: 1]
- **Link to Specific Heading/Chapter:** `[[Note_Name(Heading Title)]]`[cite: 1]

### 5. Local Asset Manager (Double Bang `!!`)
- Use `!![alt_text](url_or_path)` instead of standard `![alt_text](url)` when embedding external images or media that should be automatically cached and downloaded into the local `.assets/` directory[cite: 1].