use crate::api::chat::open_db;
use fastembed::{TextEmbedding, InitOptions, EmbeddingModel};
use rusqlite::{params, Result as RusqliteResult};
use serde::{Deserialize, Serialize};
use std::sync::{OnceLock, Mutex};

static EMBEDDER: OnceLock<Mutex<TextEmbedding>> = OnceLock::new();

/// Vide la base vectorielle
pub fn clear_index(wiki_root: String) -> Result<bool, String> {
    let db_path = std::path::Path::new(&wiki_root).join(".crowchat");
    let conn = rusqlite::Connection::open(&db_path).map_err(|e| e.to_string())?;
    
    conn.execute("DELETE FROM vec_chunks", []).map_err(|e| e.to_string())?;
    conn.execute("DELETE FROM wiki_chunks", []).map_err(|e| e.to_string())?;
    
    Ok(true)
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[flutter_rust_bridge::frb]
pub struct ChunkResult {
    pub file_path: String,
    pub chunk_text: String,
    pub distance: f64,
}

/// Initialise le modèle d'embedding en mémoire
pub fn init_embedder() -> Result<bool, String> {
    if EMBEDDER.get().is_none() {
        // We use AllMiniLML6V2, a very lightweight and fast model producing 384d vectors
        let model = TextEmbedding::try_new(
            InitOptions::new(EmbeddingModel::AllMiniLML6V2).with_show_download_progress(true)
        )
        .map_err(|e| format!("Failed to init embedder: {}", e))?;
        
        let _ = EMBEDDER.set(Mutex::new(model));
    }
    Ok(true)
}

/// Helper pour convertir Vec<f32> en &[u8] pour sqlite-vec
fn f32_vec_to_bytes(vec: &[f32]) -> &[u8] {
    unsafe {
        std::slice::from_raw_parts(
            vec.as_ptr() as *const u8,
            vec.len() * std::mem::size_of::<f32>(),
        )
    }
}

/// Indexe le contenu d'un fichier dans la base vectorielle
pub fn index_file(wiki_root: String, file_path: String, content: String) -> Result<bool, String> {
    if EMBEDDER.get().is_none() {
        init_embedder()?;
    }
    let mut embedder_lock = EMBEDDER.get().ok_or("Embedder init failed.")?.lock().map_err(|e| e.to_string())?;
    
    // 1. Simple chunking strategy: split by double newlines, group up to 500 chars
    let mut chunks = Vec::new();
    let paragraphs: Vec<&str> = content.split("\n\n").collect();
    
    let mut current_chunk = String::new();
    for p in paragraphs {
        if p.trim().is_empty() { continue; }
        
        if current_chunk.len() + p.len() > 500 && !current_chunk.is_empty() {
            chunks.push(current_chunk.clone());
            current_chunk.clear();
        }
        
        if !current_chunk.is_empty() {
            current_chunk.push_str("\n\n");
        }
        current_chunk.push_str(p.trim());
    }
    if !current_chunk.is_empty() {
        chunks.push(current_chunk);
    }
    
    if chunks.is_empty() {
        return Ok(true);
    }

    // 2. Generate embeddings for all chunks in batch
    let embeddings = embedder_lock.embed(chunks.clone(), None)
        .map_err(|e| format!("Failed to generate embeddings: {}", e))?;

    // 3. Insert into SQLite
    let db_path = std::path::Path::new(&wiki_root).join(".crowchat");
    let mut conn = rusqlite::Connection::open(&db_path).map_err(|e| e.to_string())?;
    
    let tx = conn.transaction().map_err(|e| e.to_string())?;
    
    // Delete old chunks for this file
    tx.execute(
        "DELETE FROM vec_chunks WHERE rowid IN (SELECT id FROM wiki_chunks WHERE file_path = ?1)",
        params![file_path]
    ).map_err(|e| e.to_string())?;
    tx.execute(
        "DELETE FROM wiki_chunks WHERE file_path = ?1",
        params![file_path]
    ).map_err(|e| e.to_string())?;
    
    for (i, embedding) in embeddings.iter().enumerate() {
        let chunk_text = &chunks[i];
        let bytes = f32_vec_to_bytes(embedding);
        
        // Insert vector
        tx.execute(
            "INSERT INTO vec_chunks (embedding) VALUES (?1)",
            params![bytes]
        ).map_err(|e| e.to_string())?;
        
        let chunk_id = tx.last_insert_rowid();
        
        // Insert metadata
        tx.execute(
            "INSERT INTO wiki_chunks (id, file_path, chunk_text) VALUES (?1, ?2, ?3)",
            params![chunk_id, file_path, chunk_text]
        ).map_err(|e| e.to_string())?;
    }
    
    tx.commit().map_err(|e| e.to_string())?;
    
    Ok(true)
}

/// Cherche les documents similaires dans le wiki
pub fn search_similar(wiki_root: String, query: String, limit: usize) -> Result<Vec<ChunkResult>, String> {
    if EMBEDDER.get().is_none() {
        init_embedder()?;
    }
    let mut embedder_lock = EMBEDDER.get().ok_or("Embedder init failed.")?.lock().map_err(|e| e.to_string())?;
    
    // Embed the query
    let embeddings = embedder_lock.embed(vec![query], None)
        .map_err(|e| format!("Failed to embed query: {}", e))?;
        
    let query_embedding = &embeddings[0];
    let bytes = f32_vec_to_bytes(query_embedding);
    
    let conn = open_db(&wiki_root)?;
    
    // Perform vector search
    let mut stmt = conn.prepare(
        "
        SELECT wiki_chunks.file_path, wiki_chunks.chunk_text, vec_chunks.distance
        FROM vec_chunks
        LEFT JOIN wiki_chunks ON wiki_chunks.id = vec_chunks.rowid
        WHERE vec_chunks.embedding MATCH ? AND k = ?
        ORDER BY vec_chunks.distance
        "
    ).map_err(|e| e.to_string())?;
    
    let chunk_iter = stmt.query_map(params![bytes, limit as i64], |row| {
        Ok(ChunkResult {
            file_path: row.get(0)?,
            chunk_text: row.get(1)?,
            distance: row.get(2)?,
        })
    }).map_err(|e| e.to_string())?;
    
    let mut results = Vec::new();
    for chunk in chunk_iter {
        if let Ok(c) = chunk {
            results.push(c);
        }
    }
    
    Ok(results)
}
