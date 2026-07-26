use crate::api::models::{CrowFile, CrowMetadata, Page, PageMetadata, TreeNode};
use base64::{engine::general_purpose, Engine as _};
use chrono::Utc;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

pub fn init_wiki(root_path: String, title: String) -> anyhow::Result<()> {
    let root = Path::new(&root_path);
    if !root.exists() {
        fs::create_dir_all(root)?;
    }
    
    let metadata = CrowMetadata {
        title,
        version: "2.0".to_string(),
        created_at: Some(Utc::now().timestamp()),
        updated_at: Some(Utc::now().timestamp()),
    };
    
    let crow_file = CrowFile {
        metadata,
        settings: "".to_string(),
        modules: "".to_string(),
    };
    
    write_anchor(root_path, crow_file)?;
    Ok(())
}

fn obfuscate(data: &str, key: u8) -> String {
    let xored: Vec<u8> = data.bytes().map(|b| b ^ key).collect();
    general_purpose::STANDARD.encode(&xored)
}

fn deobfuscate(b64: &str, key: u8) -> Option<String> {
    if let Ok(decoded) = general_purpose::STANDARD.decode(b64) {
        let xored: Vec<u8> = decoded.into_iter().map(|b| b ^ key).collect();
        if let Ok(s) = String::from_utf8(xored) {
            return Some(s);
        }
    }
    None
}

pub fn write_anchor(root_path: String, crow_file: CrowFile) -> anyhow::Result<()> {
    let anchor_path = Path::new(&root_path).join(".crow");
    let json_meta = serde_json::to_string(&crow_file.metadata)?;
    
    // Obfuscate with 3 different keys so the blocks look completely different
    let b1 = obfuscate(&json_meta, 0x42);
    let b2 = obfuscate(&json_meta, 0x73);
    let b3 = obfuscate(&json_meta, 0x91);
    
    let redundancy = format!("{}.{}.{}", b1, b2, b3);
    
    let content = format!(
        "{}\n---\n{}\n---\n{}",
        redundancy,
        crow_file.settings,
        crow_file.modules
    );
    
    fs::write(anchor_path, content)?;
    Ok(())
}

pub fn read_anchor(root_path: String) -> anyhow::Result<CrowFile> {
    let anchor_path = Path::new(&root_path).join(".crow");
    let content = fs::read_to_string(anchor_path)?;
    
    let parts: Vec<&str> = content.split("\n---\n").collect();
    
    // Parse metadata
    let metadata_str = parts.get(0).unwrap_or(&"");
    let b64_blocks: Vec<&str> = metadata_str.split('.').collect();
    
    let keys = [0x42, 0x73, 0x91];
    let mut vote_map: HashMap<String, usize> = HashMap::new();
    
    for (i, block) in b64_blocks.iter().enumerate() {
        let block = block.trim();
        if !block.is_empty() {
            let key = *keys.get(i).unwrap_or(&0x42); // Fallback key if too many blocks
            if let Some(decrypted_json) = deobfuscate(block, key) {
                *vote_map.entry(decrypted_json).or_insert(0) += 1;
            }
        }
    }
    
    let mut best_json = String::new();
    let mut max_votes = 0;
    for (json, count) in vote_map {
        if count > max_votes {
            max_votes = count;
            best_json = json;
        }
    }
    
    let metadata: CrowMetadata = if !best_json.is_empty() {
        serde_json::from_str(&best_json).unwrap_or_default()
    } else {
        CrowMetadata::default()
    };
    
    let settings = parts.get(1).unwrap_or(&"").to_string();
    let modules = parts.get(2).unwrap_or(&"").to_string();
    
    Ok(CrowFile {
        metadata,
        settings,
        modules,
    })
}

pub fn scan_directory(root_path: String) -> anyhow::Result<TreeNode> {
    let root = Path::new(&root_path);
    scan_dir_recursive(root, root)
}

fn scan_dir_recursive(path: &Path, root: &Path) -> anyhow::Result<TreeNode> {
    let mut children = Vec::new();
    let name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();
    let rel_path = path
        .strip_prefix(root)?
        .to_string_lossy()
        .to_string()
        .replace("\\", "/");

    if path.is_dir() {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let entry_path = entry.path();
            let file_name = entry.file_name().to_string_lossy().to_string();

            // Ignore hidden files like .git, etc. but keep .crow and .crowstyle
            if file_name.starts_with('.') && !file_name.ends_with(".crow") && !file_name.ends_with(".crowstyle") {
                continue;
            }

            if entry_path.is_dir() {
                if let Ok(node) = scan_dir_recursive(&entry_path, root) {
                    children.push(node);
                }
            } else {
                let allowed = ["md", "crow", "crowstyle", "png", "mp3", "mp4"];
                let is_allowed = allowed.iter().any(|a| file_name.ends_with(&format!(".{}", a))) 
                                 || file_name == ".crow" 
                                 || file_name == ".crowstyle";

                if is_allowed {
                    let mut display_name = file_name.clone();
                    if display_name.ends_with(".md") {
                        display_name = display_name.replace(".md", "");
                    }
                    children.push(TreeNode {
                        name: display_name,
                        path: entry_path
                            .strip_prefix(root)?
                            .to_string_lossy()
                            .to_string()
                            .replace("\\", "/"),
                        is_directory: false,
                        children: Vec::new(),
                    });
                }
            }
        }
    }

    // Sort: directories first, then alphabetically
    children.sort_by(|a, b| {
        b.is_directory
            .cmp(&a.is_directory)
            .then(a.name.cmp(&b.name))
    });

    Ok(TreeNode {
        name: if rel_path.is_empty() {
            "Root".to_string()
        } else {
            name
        },
        path: rel_path,
        is_directory: true,
        children,
    })
}

pub fn read_page(root_path: String, rel_path: String) -> anyhow::Result<Page> {
    let file_path = Path::new(&root_path).join(&rel_path);
    let content = fs::read_to_string(file_path)?;

    // Parse Frontmatter
    let mut metadata = PageMetadata {
        title: Path::new(&rel_path)
            .file_stem()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string(),
        tags: vec![],
        created_at: None,
        updated_at: None,
    };
    let mut markdown_content = content.clone();

    if content.starts_with("---\n") || content.starts_with("---\r\n") {
        if let Some(end) = content[4..].find("\n---") {
            let yaml_str = &content[4..end + 4];
            if let Ok(parsed_meta) = serde_yaml::from_str::<PageMetadata>(yaml_str) {
                metadata = parsed_meta;
            }
            // Add + 4 for "\n---" and + 1 for newline after that
            let end_idx = end + 8;
            if end_idx < content.len() {
                markdown_content = content[end_idx..].trim_start().to_string();
            } else {
                markdown_content = String::new();
            }
        }
    }

    Ok(Page {
        path: rel_path,
        metadata,
        content: markdown_content,
    })
}

pub fn write_page(root_path: String, rel_path: String, page: Page) -> anyhow::Result<()> {
    let file_path = Path::new(&root_path).join(&rel_path);
    if let Some(parent) = file_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let mut updated_meta = page.metadata;
    updated_meta.updated_at = Some(Utc::now().timestamp());

    let yaml_str = serde_yaml::to_string(&updated_meta)?;
    let final_content = format!("---\n{}---\n\n{}", yaml_str.trim(), page.content);

    fs::write(file_path, final_content)?;
    Ok(())
}

pub fn create_file(path: String) -> anyhow::Result<()> {
    let p = Path::new(&path);
    if let Some(parent) = p.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::File::create(p)?;
    log::info!("Created file: {}", path);
    Ok(())
}

pub fn create_directory(path: String) -> anyhow::Result<()> {
    fs::create_dir_all(&path)?;
    log::info!("Created directory: {}", path);
    Ok(())
}

pub fn delete_item(path: String) -> anyhow::Result<()> {
    let p = Path::new(&path);
    if p.is_dir() {
        fs::remove_dir_all(p)?;
        log::info!("Deleted directory: {}", path);
    } else if p.is_file() {
        fs::remove_file(p)?;
        log::info!("Deleted file: {}", path);
    }
    Ok(())
}

pub fn rename_item(old_path: String, new_path: String) -> anyhow::Result<()> {
    let new_p = Path::new(&new_path);
    if let Some(parent) = new_p.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::rename(&old_path, &new_path)?;
    log::info!("Renamed item from {} to {}", old_path, new_path);
    Ok(())
}

pub fn read_file_as_string(path: String) -> anyhow::Result<String> {
    let content = fs::read_to_string(&path)?;
    Ok(content)
}

pub fn write_file_as_string(path: String, content: String) -> anyhow::Result<()> {
    let p = Path::new(&path);
    if let Some(parent) = p.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(p, content)?;
    log::info!("Written to file: {}", path);
    Ok(())
}
