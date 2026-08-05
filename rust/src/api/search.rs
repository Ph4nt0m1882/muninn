use pulldown_cmark::{Event, Parser};
use rusqlite::{params, Connection, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::sync::{Mutex, OnceLock};
use walkdir::WalkDir;

// Un mutex global pour garder la connexion ouverte (optionnel, mais plus performant)
static DB_CONN: OnceLock<Mutex<Connection>> = OnceLock::new();

#[derive(Debug, Serialize, Deserialize, Clone)]
#[flutter_rust_bridge::frb]
pub struct DbHealthStatus {
    pub status: String,
    pub message: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SourceMapping {
    pub rendered_start: usize,
    pub rendered_end: usize,
    pub raw_start: usize,
    pub raw_end: usize,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[flutter_rust_bridge::frb]
pub struct SearchResult {
    pub file_path: String,
    pub raw_start_offset: usize,
    pub raw_end_offset: usize,
    pub exact_match_text: String,
    pub preview_text: String,
    pub line_number: usize,
    pub column_number: usize,
    pub is_case_match: bool,
    pub is_syntax_clean: bool,
    pub is_whole_word: bool,
}

/// Initialise la base de données .crowindex pour un wiki donné
#[flutter_rust_bridge::frb(sync)]
pub fn init_search_db(wiki_root: String) -> Result<bool, String> {
    let db_path = Path::new(&wiki_root).join(".crowindex");
    let conn = Connection::open(&db_path).map_err(|e| e.to_string())?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS documents (
            file_path TEXT PRIMARY KEY,
            raw_text TEXT NOT NULL,
            rendered_text TEXT NOT NULL,
            source_map BLOB NOT NULL,
            vector_data BLOB
        )",
        [],
    )
    .map_err(|e| e.to_string())?;

    // On stocke la connexion dans le singleton
    let _ = DB_CONN.set(Mutex::new(conn));

    Ok(true)
}

/// Extrait le texte pur et génère la Source Map d'un fichier Markdown
fn extract_rendered_text_and_map(raw_markdown: &str) -> (String, Vec<SourceMapping>) {
    let parser = Parser::new_ext(raw_markdown, pulldown_cmark::Options::all());
    let mut rendered_text = String::new();
    let mut source_maps = Vec::new();

    for (event, range) in parser.into_offset_iter() {
        match event {
            Event::Text(text) | Event::Code(text) => {
                let start = rendered_text.len();
                rendered_text.push_str(&text);
                let end = rendered_text.len();

                source_maps.push(SourceMapping {
                    rendered_start: start,
                    rendered_end: end,
                    raw_start: range.start,
                    raw_end: range.end,
                });
            }
            Event::SoftBreak | Event::HardBreak => {
                rendered_text.push('\n');
            }
            _ => {}
        }
    }

    (rendered_text, source_maps)
}

/// Indexe un fichier (le lit, le parse, et le stocke dans la DB)
#[flutter_rust_bridge::frb(sync)]
pub fn index_document(file_path: String, raw_markdown: String) -> Result<bool, String> {
    let conn_guard = DB_CONN
        .get()
        .ok_or("Database not initialized")?
        .lock()
        .unwrap();

    let (rendered_text, source_map) = extract_rendered_text_and_map(&raw_markdown);
    let source_map_json = serde_json::to_string(&source_map).map_err(|e| e.to_string())?;

    conn_guard
        .execute(
            "INSERT INTO documents (file_path, raw_text, rendered_text, source_map) 
         VALUES (?1, ?2, ?3, ?4)
         ON CONFLICT(file_path) DO UPDATE SET 
            raw_text=excluded.raw_text, 
            rendered_text=excluded.rendered_text, 
            source_map=excluded.source_map",
            params![
                file_path,
                raw_markdown,
                rendered_text,
                source_map_json.as_bytes()
            ],
        )
        .map_err(|e| e.to_string())?;

    Ok(true)
}

/// Recherche dans la base de données
#[flutter_rust_bridge::frb(sync)]
pub fn search_documents(query: String, mode: u8) -> Result<Vec<SearchResult>, String> {
    let conn_guard = DB_CONN
        .get()
        .ok_or("Database not initialized")?
        .lock()
        .unwrap();
    let mut results = Vec::new();

    let query_lower = query.to_lowercase();
    if query_lower.is_empty() {
        return Ok(results);
    }

    let mut stmt = conn_guard
        .prepare("SELECT file_path, raw_text, rendered_text, source_map FROM documents")
        .map_err(|e| e.to_string())?;

    let mut rows = stmt.query([]).map_err(|e| e.to_string())?;

    while let Some(row) = rows.next().map_err(|e| e.to_string())? {
        let file_path: String = row.get(0).map_err(|e| e.to_string())?;
        let raw_text: String = row.get(1).map_err(|e| e.to_string())?;
        let rendered_text: String = row.get(2).map_err(|e| e.to_string())?;
        let source_map_bytes: Vec<u8> = row.get(3).map_err(|e| e.to_string())?;

        let source_maps: Vec<SourceMapping> =
            serde_json::from_slice(&source_map_bytes).unwrap_or_default();

        if mode == 1 {
            // Mode Brut (recherche dans raw_text)
            let lower_raw = raw_text.to_lowercase();
            for (idx, _) in lower_raw.match_indices(&query_lower) {
                let start = idx;
                let end = idx + query_lower.len(); // use byte length of lower query

                let utf16_start = utf16_offset(&lower_raw, start);
                let utf16_end = utf16_offset(&lower_raw, end);

                let exact_match_text = safe_slice(&raw_text, start, end);
                let is_case_match = exact_match_text == query;
                let is_syntax_clean = !exact_match_text.contains(|c| "*_#`~[]()!".contains(c));
                let is_whole_word = check_whole_word(&raw_text, start, end);
                let (line_number, column_number) = calculate_line_col(&raw_text, start);

                // Extraire une preview (max 100 caractères)
                let preview_start = start.saturating_sub(20);
                let preview_end = end + 80;
                let preview = format!(
                    "...{}...",
                    safe_slice(&raw_text, preview_start, preview_end)
                );

                results.push(SearchResult {
                    file_path: file_path.clone(),
                    raw_start_offset: utf16_start,
                    raw_end_offset: utf16_end,
                    exact_match_text,
                    preview_text: preview.replace('\n', " "),
                    line_number,
                    column_number,
                    is_case_match,
                    is_syntax_clean,
                    is_whole_word,
                });
            }
        } else if mode == 2 {
            // Mode Rendu (recherche dans rendered_text)
            let lower_rendered = rendered_text.to_lowercase();
            for (idx, _) in lower_rendered.match_indices(&query_lower) {
                let rendered_start = idx;
                let rendered_end = idx + query_lower.len();

                // Convertir les offsets rendered vers raw en utilisant la Source Map
                let mut raw_start = 0;
                let mut raw_end = 0;

                for map in &source_maps {
                    if map.rendered_start <= rendered_start && map.rendered_end >= rendered_start {
                        raw_start = map.raw_start + (rendered_start - map.rendered_start);
                    }
                    if map.rendered_start <= rendered_end && map.rendered_end >= rendered_end {
                        raw_end = map.raw_start + (rendered_end - map.rendered_start);
                    }
                }

                if raw_start > 0 || raw_end > 0 {
                    let utf16_start = utf16_offset(&raw_text, raw_start);
                    let utf16_end = utf16_offset(&raw_text, raw_end);

                    let exact_match_text = safe_slice(&raw_text, raw_start, raw_end);
                    let is_case_match = exact_match_text == query;
                    let is_syntax_clean = !exact_match_text.contains(|c| "*_#`~[]()!".contains(c));
                    let is_whole_word = check_whole_word(&raw_text, raw_start, raw_end);
                    let (line_number, column_number) = calculate_line_col(&raw_text, raw_start);

                    // Extraire preview depuis rendered_text pour bien montrer la différence avec Brut
                    let preview_start = rendered_start.saturating_sub(20);
                    let preview_end = rendered_end + 80;
                    let preview = format!(
                        "...{}...",
                        safe_slice(&rendered_text, preview_start, preview_end)
                    );

                    results.push(SearchResult {
                        file_path: file_path.clone(),
                        raw_start_offset: utf16_start,
                        raw_end_offset: utf16_end,
                        exact_match_text,
                        preview_text: preview.replace('\n', " "),
                        line_number,
                        column_number,
                        is_case_match,
                        is_syntax_clean,
                        is_whole_word,
                    });
                }
            }
        }
    }

    Ok(results)
}

#[flutter_rust_bridge::frb(sync)]
pub fn check_db_health(wiki_root: String) -> DbHealthStatus {
    let db_path = std::path::Path::new(&wiki_root).join(".crowindex");
    if !db_path.exists() {
        return DbHealthStatus {
            status: "missing".into(),
            message: "".into(),
        };
    }

    let conn = match Connection::open(&db_path) {
        Ok(c) => c,
        Err(e) => {
            return DbHealthStatus {
                status: "corrupted".into(),
                message: format!("Cannot open DB: {}", e),
            }
        }
    };

    let mut stmt = match conn.prepare("PRAGMA integrity_check") {
        Ok(s) => s,
        Err(e) => {
            return DbHealthStatus {
                status: "corrupted".into(),
                message: format!("PRAGMA failed: {}", e),
            }
        }
    };

    let mut rows = match stmt.query([]) {
        Ok(r) => r,
        Err(e) => {
            return DbHealthStatus {
                status: "corrupted".into(),
                message: format!("Query failed: {}", e),
            }
        }
    };

    if let Ok(Some(row)) = rows.next() {
        let result: String = row.get(0).unwrap_or_default();
        if result.to_lowercase() != "ok" {
            return DbHealthStatus {
                status: "corrupted".into(),
                message: format!("Integrity check failed: {}", result),
            };
        }
    } else {
        return DbHealthStatus {
            status: "corrupted".into(),
            message: "No result from integrity check".into(),
        };
    }

    let mut table_check = match conn
        .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='documents'")
    {
        Ok(s) => s,
        Err(e) => {
            return DbHealthStatus {
                status: "corrupted".into(),
                message: format!("Table check failed: {}", e),
            }
        }
    };

    if let Ok(mut rows) = table_check.query([]) {
        if let Ok(Some(_)) = rows.next() {
            return DbHealthStatus {
                status: "healthy".into(),
                message: "".into(),
            };
        }
    }

    DbHealthStatus {
        status: "corrupted".into(),
        message: "Table 'documents' is missing".into(),
    }
}

pub fn rebuild_index(wiki_root: String) -> Result<bool, String> {
    let conn_res = init_search_db(wiki_root.clone());
    if conn_res.is_err() {
        return Err("Failed to init db for rebuild".into());
    }

    let conn_guard = DB_CONN
        .get()
        .ok_or("Database not initialized")?
        .lock()
        .unwrap();
    conn_guard
        .execute("DELETE FROM documents", [])
        .map_err(|e| e.to_string())?;

    let walker = WalkDir::new(&wiki_root)
        .follow_links(true)
        .into_iter()
        .filter_entry(|e| {
            !e.file_name()
                .to_str()
                .map(|s| s.starts_with('.'))
                .unwrap_or(false)
        });

    for entry in walker.filter_map(|e| e.ok()) {
        if entry.file_type().is_file() {
            if let Some(ext) = entry.path().extension() {
                if ext == "md" {
                    if let Ok(content) = fs::read_to_string(entry.path()) {
                        let path_str = entry.path().to_string_lossy().to_string();
                        let (rendered_text, source_map) = extract_rendered_text_and_map(&content);
                        if let Ok(source_map_json) = serde_json::to_string(&source_map) {
                            let _ = conn_guard.execute(
                                "INSERT INTO documents (file_path, raw_text, rendered_text, source_map) 
                                 VALUES (?1, ?2, ?3, ?4)
                                 ON CONFLICT(file_path) DO UPDATE SET 
                                    raw_text=excluded.raw_text, 
                                    rendered_text=excluded.rendered_text, 
                                    source_map=excluded.source_map",
                                params![path_str, content, rendered_text, source_map_json.as_bytes()],
                            );
                        }
                    }
                }
            }
        }
    }

    Ok(true)
}

fn utf16_offset(s: &str, byte_idx: usize) -> usize {
    let mut safe_idx = byte_idx;
    while safe_idx > 0 && !s.is_char_boundary(safe_idx) {
        safe_idx -= 1;
    }
    s[..safe_idx].chars().map(|c| c.len_utf16()).sum()
}

fn calculate_line_col(text: &str, byte_offset: usize) -> (usize, usize) {
    let mut line = 1;
    let mut last_newline = 0;

    // safety check
    let safe_offset = byte_offset.min(text.len());

    for (i, c) in text[..safe_offset].char_indices() {
        if c == '\n' {
            line += 1;
            last_newline = i + 1;
        }
    }

    let column = text[last_newline..safe_offset].chars().count() + 1;
    (line, column)
}

fn check_whole_word(text: &str, start: usize, end: usize) -> bool {
    let mut is_whole = true;
    if start > 0 {
        if let Some(c) = text[..start].chars().last() {
            if c.is_alphanumeric() || c == '_' {
                is_whole = false;
            }
        }
    }
    if end < text.len() {
        if let Some(c) = text[end..].chars().next() {
            if c.is_alphanumeric() || c == '_' {
                is_whole = false;
            }
        }
    }
    is_whole
}

fn safe_slice(text: &str, start: usize, end: usize) -> String {
    let mut s = start.min(text.len());
    while s > 0 && !text.is_char_boundary(s) {
        s -= 1;
    }
    let mut e = end.min(text.len());
    while e < text.len() && !text.is_char_boundary(e) {
        e += 1;
    }
    if s <= e {
        text[s..e].to_string()
    } else {
        String::new()
    }
}
