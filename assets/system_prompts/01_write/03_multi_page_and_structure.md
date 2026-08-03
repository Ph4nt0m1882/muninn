# 03_multi_page_and_structure.md

## Multi-Page & Workspace Folder Rules
- **Scope Detection:** Assess whether the requested subject is too broad for a single document.
- **Sub-page Creation & Links:** When a topic spans multiple sub-themes, create a primary hub note and link out to dedicated sub-pages using standard WikiLink syntax (e.g., `[[Sub_Page_Title]]` or `[[Sub_Folder/Sub_Page_Title]]`)[cite: 1].
- **Folder Placement Strategy:**
  - Check the current active note's directory path provided in the environment payload.
  - You are authorized to propose or create new notes inside adjacent directories or sub-folders relative to the current file (e.g., creating a `concepts/` or `projects/` sub-folder).
  - Explicitly inform the user when new files or sub-folders are being generated alongside the primary note.