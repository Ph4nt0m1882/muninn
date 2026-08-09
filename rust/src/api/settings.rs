use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
#[serde(default)]
pub struct AppSettings {
    pub theme_index: i32,
    pub recent_wikis: Vec<String>,
    pub google_api_key: Option<String>,
}

/// Helper pour obtenir le chemin du fichier de configuration
fn get_settings_path() -> Option<PathBuf> {
    if let Some(proj_dirs) = ProjectDirs::from("com", "muninn", "Muninn") {
        let config_dir = proj_dirs.config_dir();

        // S'assurer que le dossier existe
        if !config_dir.exists() {
            let _ = fs::create_dir_all(config_dir);
        }

        Some(config_dir.join("settings.yaml"))
    } else {
        None
    }
}

/// Charge les paramètres depuis le fichier de config (crée par défaut si absent)
#[flutter_rust_bridge::frb(sync)]
pub fn load_settings() -> AppSettings {
    if let Some(path) = get_settings_path() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(settings) = serde_yaml::from_str::<AppSettings>(&content) {
                return settings;
            }
        }
    }
    AppSettings::default()
}

/// Sauvegarde les paramètres actuels
fn save_settings(settings: &AppSettings) {
    if let Some(path) = get_settings_path() {
        if let Ok(yaml) = serde_yaml::to_string(settings) {
            let _ = fs::write(path, yaml);
        }
    }
}

/// Met à jour l'index du thème
#[flutter_rust_bridge::frb(sync)]
pub fn save_theme(index: i32) {
    let mut settings = load_settings();
    settings.theme_index = index;
    save_settings(&settings);
}

/// Sauvegarde la clé d'API Google
#[flutter_rust_bridge::frb(sync)]
pub fn save_google_api_key(key: String) {
    let mut settings = load_settings();
    settings.google_api_key = Some(key);
    save_settings(&settings);
}

/// Ajoute un wiki à l'historique récent
#[flutter_rust_bridge::frb(sync)]
pub fn add_recent_wiki(wiki_path: String) {
    let mut settings = load_settings();

    // Enlever le wiki s'il est déjà dans la liste pour éviter les doublons
    settings.recent_wikis.retain(|p| p != &wiki_path);

    // L'ajouter au début (le plus récent)
    settings.recent_wikis.insert(0, wiki_path);

    // Garder seulement les 10 derniers wikis par exemple
    settings.recent_wikis.truncate(10);

    save_settings(&settings);
}
