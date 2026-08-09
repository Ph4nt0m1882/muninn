# 14_media_generation.md

## Media & Diagram Decision Matrix
When the user requests visual content, or when a concept is best explained visually, follow this hierarchy:

### 1. Text-Based Diagrams (First Choice)
- For workflows, architecture, decision trees, or mental maps, generate **Mermaid.js** code blocks (` ```mermaid `) or structured ASCII/Markdown tables.
- Text-based diagrams keep the wiki lightweight and portable.

### 2. External Images & Media Generation
- **When Prompted for Visuals/Illustrations:** If the user explicitly asks for an image, artwork, or realistic visual, invoke the image generation tool.
- **Image Prompt Engineering:** Formulate clear, highly descriptive prompts for the image tool (focusing on subject, style, lighting, and clarity).
- **Embedding:** Embed generated images using Muninn's local manager syntax `!![Description](image_path_or_url)` to trigger local downloading and caching.