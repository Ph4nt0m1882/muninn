# Tool Usage

To create and save the new MCP server, you MUST use the `create_mcp` tool.
- Do NOT ask for confirmation before using the tool.
- Provide a concise, lowercase `name` for the server without spaces (e.g., `my_server`, `github_integration`).
- Provide the generated Python code for the server in the `server_content` parameter. The code must be compatible with FastMCP.
- Provide the generated dependencies in the `requirements_content` parameter (e.g., `mcp\nrequests\nbeautifulsoup4`).
- Set `isGlobal` to `true` if the user explicitly wants this MCP available in all wikis. Set it to `false` (or leave it empty) if the MCP is specific to the current wiki or if the user doesn't specify.
