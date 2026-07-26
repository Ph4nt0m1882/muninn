use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CrowMetadata {
    pub title: String,
    pub version: String,
    pub created_at: Option<i64>,
    pub updated_at: Option<i64>,
}

impl Default for CrowMetadata {
    fn default() -> Self {
        Self {
            title: "Mon Wiki".to_string(),
            version: "2.0".to_string(),
            created_at: None,
            updated_at: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CrowFile {
    pub metadata: CrowMetadata,
    pub settings: String, // YAML string
    pub modules: String, // YAML/JSON string
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PageMetadata {
    pub title: String,
    #[serde(default)]
    pub tags: Vec<String>,
    pub created_at: Option<i64>,
    pub updated_at: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct Page {
    pub path: String, // Relative to the wiki root
    pub metadata: PageMetadata,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct TreeNode {
    pub name: String,
    pub path: String,
    pub is_directory: bool,
    pub children: Vec<TreeNode>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TextAttributes {
    #[serde(default)]
    pub bold: bool,
    #[serde(default)]
    pub italic: bool,
    #[serde(default)]
    pub strikethrough: bool,
    #[serde(default)]
    pub code: bool,
    #[serde(default)]
    pub link: Option<String>,
    #[serde(default)]
    pub header: Option<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextChunk {
    pub text: String,
    pub attributes: TextAttributes,
}
