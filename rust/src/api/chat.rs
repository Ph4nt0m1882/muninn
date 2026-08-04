use rusqlite::{params, Connection, Result};
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[flutter_rust_bridge::frb]
pub struct ChatMessage {
    pub id: String,
    pub session_id: String,
    pub role: String, // "user" or "model"
    pub content: String,
    pub timestamp: i64,
    pub sources: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[flutter_rust_bridge::frb]
pub struct ChatSession {
    pub id: String,
    pub title: String,
    pub created_at: i64,
    pub updated_at: i64,
}

use rusqlite::ffi::sqlite3_auto_extension;
use std::sync::Once;

static INIT_SQLITE_VEC: Once = Once::new();

pub(crate) fn open_db(wiki_root: &str) -> Result<Connection, String> {
    // Initialize sqlite-vec globally for all rusqlite connections
    INIT_SQLITE_VEC.call_once(|| {
        unsafe {
            sqlite3_auto_extension(Some(std::mem::transmute(
                sqlite_vec::sqlite3_vec_init as *const (),
            )));
        }
    });

    let db_path = Path::new(wiki_root).join(".crowchat");
    let conn = Connection::open(&db_path).map_err(|e| e.to_string())?;
    
    Ok(conn)
}

/// Initialise la base de données de chat
#[flutter_rust_bridge::frb(sync)]
pub fn init_chat_db(wiki_root: String) -> Result<bool, String> {
    let conn = open_db(&wiki_root)?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS chat_sessions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )",
        [],
    )
    .map_err(|e| e.to_string())?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            sources TEXT,
            FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
        )",
        [],
    )
    .map_err(|e| e.to_string())?;

    // Migration in case the DB existed before we added sources
    let _ = conn.execute("ALTER TABLE chat_messages ADD COLUMN sources TEXT", []);

    // Create the virtual table for embeddings (using 384 dimensions for all-MiniLM-L6-v2)
    conn.execute(
        "CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
            embedding float[384]
        )",
        [],
    )
    .map_err(|e| e.to_string())?;

    // Create the standard table to hold the text and metadata for each chunk
    conn.execute(
        "CREATE TABLE IF NOT EXISTS wiki_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL,
            chunk_text TEXT NOT NULL,
            rowid INTEGER
        )",
        [],
    )
    .map_err(|e| e.to_string())?;

    Ok(true)
}

/// Sauvegarde une nouvelle session
#[flutter_rust_bridge::frb(sync)]
pub fn save_chat_session(wiki_root: String, session: ChatSession) -> Result<bool, String> {
    let db_path = Path::new(&wiki_root).join(".crowchat");
    let conn = Connection::open(&db_path).map_err(|e| e.to_string())?;

    conn.execute(
        "INSERT OR REPLACE INTO chat_sessions (id, title, created_at, updated_at) VALUES (?1, ?2, ?3, ?4)",
        params![session.id, session.title, session.created_at, session.updated_at],
    )
    .map_err(|e| e.to_string())?;

    Ok(true)
}

/// Liste toutes les sessions
#[flutter_rust_bridge::frb(sync)]
pub fn get_chat_sessions(wiki_root: String) -> Result<Vec<ChatSession>, String> {
    let db_path = Path::new(&wiki_root).join(".crowchat");
    let conn = Connection::open(&db_path).map_err(|e| e.to_string())?;

    let mut stmt = conn
        .prepare("SELECT id, title, created_at, updated_at FROM chat_sessions ORDER BY updated_at DESC")
        .map_err(|e| e.to_string())?;
    
    let iter = stmt
        .query_map([], |row| {
            Ok(ChatSession {
                id: row.get(0)?,
                title: row.get(1)?,
                created_at: row.get(2)?,
                updated_at: row.get(3)?,
            })
        })
        .map_err(|e| e.to_string())?;

    let mut sessions = Vec::new();
    for s in iter {
        if let Ok(session) = s {
            sessions.push(session);
        }
    }

    Ok(sessions)
}

/// Sauvegarde un message
#[flutter_rust_bridge::frb(sync)]
pub fn save_chat_message(wiki_root: String, message: ChatMessage) -> Result<bool, String> {
    let db_path = Path::new(&wiki_root).join(".crowchat");
    let conn = Connection::open(&db_path).map_err(|e| e.to_string())?;

    let sources_json = match message.sources {
        Some(s) => Some(serde_json::to_string(&s).unwrap_or_default()),
        None => None,
    };

    conn.execute(
        "INSERT INTO chat_messages (id, session_id, role, content, timestamp, sources) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![message.id, message.session_id, message.role, message.content, message.timestamp, sources_json],
    )
    .map_err(|e| e.to_string())?;

    // Met à jour le timestamp de la session
    conn.execute(
        "UPDATE chat_sessions SET updated_at = ?1 WHERE id = ?2",
        params![message.timestamp, message.session_id],
    )
    .map_err(|e| e.to_string())?;

    Ok(true)
}

/// Récupère les messages d'une session
#[flutter_rust_bridge::frb(sync)]
pub fn get_chat_messages(wiki_root: String, session_id: String) -> Result<Vec<ChatMessage>, String> {
    let db_path = Path::new(&wiki_root).join(".crowchat");
    let conn = Connection::open(&db_path).map_err(|e| e.to_string())?;

    let mut stmt = conn
        .prepare("SELECT id, session_id, role, content, timestamp, sources FROM chat_messages WHERE session_id = ?1 ORDER BY timestamp ASC")
        .map_err(|e| e.to_string())?;
    
    let iter = stmt
        .query_map(params![session_id], |row| {
            let sources_str: Option<String> = row.get(5)?;
            let sources = sources_str.and_then(|s| serde_json::from_str(&s).ok());
            Ok(ChatMessage {
                id: row.get(0)?,
                session_id: row.get(1)?,
                role: row.get(2)?,
                content: row.get(3)?,
                timestamp: row.get(4)?,
                sources,
            })
        })
        .map_err(|e| e.to_string())?;

    let mut messages = Vec::new();
    for m in iter {
        if let Ok(msg) = m {
            messages.push(msg);
        }
    }

    Ok(messages)
}
