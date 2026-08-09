# Tool Usage

To create and save the command, you MUST use the `create_command` tool.
- Do NOT ask for confirmation before using the tool.
- Provide a concise, lowercase `name` for the command without any slash (e.g., `translate`, `format`).
- Provide the generated system prompt in the `content` parameter.
- Use the `filename` parameter to specify the markdown file name (default is `prompt.md`). If the command is complex, you are encouraged to call `create_command` multiple times with the same `name` but different `filename`s (e.g., `01_core.md`, `02_constraints.md`) to logically separate the context. The application will automatically combine all `.md` files for that command.
- Set `isGlobal` to `true` if the user explicitly wants this command available in all wikis. Set it to `false` (or leave it empty) if the command is specific to the current wiki or if the user doesn't specify.
