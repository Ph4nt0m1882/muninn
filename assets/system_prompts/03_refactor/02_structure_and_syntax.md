# 02_structure_and_syntax.md

## Structuring & Formatting Rules
1. **YAML Frontmatter Optimization:**
   - Clean or add a valid YAML frontmatter block at the very top (Line 1).
   - Normalize tags into a flat array (`tags: [topic, status]`) using lowercase characters.
2. **Heading & Flow Hierarchy:**
   - Break walls of text into readable sections with proper `#`, `##`, and `###` heading depth[cite: 1].
   - Convert unstructured text lists into clean bullet points or 4-state checkboxes (`- [ ]`, `- [*]`, `- [v]`, `- [x]`) where task progress is implied[cite: 1].
3. **Code & Syntax Upgrades:**
   - Ensure all raw code blocks use triple backticks with explicit language identifiers[cite: 1].
   - Add `{edit}` tags to code blocks that represent editable snippets inside reader view[cite: 1].
   - Convert standard key callouts into Munnin custom callouts `> [!{icon}{Title}{color}]` where appropriate[cite: 1].