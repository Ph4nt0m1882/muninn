# Tool Usage

To create and save the rule, you MUST use the `create_rule` tool.
- Do NOT ask for confirmation before using the tool.
- Provide a concise, lowercase `name` for the rule without any extension (e.g., `translate_english`, `markdown_format`).
- Provide the text of the rule in the `content` parameter.
- Set `isGlobal` to `true` if the user explicitly wants this rule applied everywhere across all wikis. Set it to `false` (or leave it empty) if the rule is specific to the current wiki or if the user doesn't specify.
