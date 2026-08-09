
fn utf16_offset(s: &str, byte_idx: usize) -> usize {
    let mut safe_idx = byte_idx;
    while safe_idx > 0 && !s.is_char_boundary(safe_idx) {
        safe_idx -= 1;
    }
    s[..safe_idx].chars().map(|c| c.len_utf16()).sum()
}

fn main() {
    let raw_text = "# Bienvenue dans Muninn ! ??\n\nVotre nouvelle base de connaissances est pr�te. Muninn n'est pas un\nsimple lecteur Markdown, c'est un environnement **interactif**.\n\nVoici un aper�u de vos pouvoirs actuels :\n\n## 0. Syntaxe de base\n\nLa syntaxe html en g�n�ral est compatible avec la syntaxe markdown\n\n### Titres :\nLes titres en markdowns sont hierarchiques";
    let lower_raw = raw_text.to_lowercase();
    let query_lower = "titres";
    
    if let Some(idx) = lower_raw.find(&query_lower) {
        let start = idx;
        let end = idx + query_lower.len();
        
        let utf16_start = utf16_offset(&lower_raw, start);
        let utf16_end = utf16_offset(&lower_raw, end);
        
        println!("byte start: {}, utf16 start: {}", start, utf16_start);
        
        // Print character at utf16 offset
        // We can't slice Dart string here easily, but we can verify how many utf16 code units
        let char_offset = utf16_offset(&raw_text, start);
        println!("byte offset difference: {}", start - utf16_start);
    }
}

