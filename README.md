# ![muninn](.github/assets/images/Header.jpeg)

**Muninn** est un éditeur Markdown de bureau moderne, réactif et visuellement dynamique, conçu pour la fluidité et le plaisir d'écriture. L'application allie la puissance d'une interface utilisateur élégante développée en Flutter à la rapidité d'exécution d'un moteur bas niveau écrit en Rust.

## ✨ Fonctionnalités Principales

- **Édition et Rendu Markdown en temps réel :** Passez d'un mode édition à un mode de rendu élégant en un instant.
- **Support des WikiLinks :** Naviguez entre vos notes avec la syntaxe `[[lien]]`. L'éditeur résout intelligemment les liens et ouvre les fichiers correspondants.
- **Gestion des onglets dynamique :** Un système d'onglets immersif avec des micro-interactions soignées (glissements, ondes lumineuses, apparitions douces).
- **Blocs de Code Interactifs :** La coloration syntaxique avancée supporte les thèmes dynamiques (monokai) et permet des interactions poussées.
- **Le Corbeau Assistant :** Parce que chaque détail compte, cliquer sur un WikiLink déclenche l'envol d'un corbeau à travers l'écran, plongeant sur l'onglet de destination pour dévoiler votre nouveau fichier.
- **Moteur Rust embarqué :** Les opérations coûteuses (recherche de fichiers, parsing intensif) sont gérées en Rust via `flutter_rust_bridge`, garantissant des performances sans compromis.

## 🛠️ Stack Technique

- **Frontend :** Flutter (Dart) pour le desktop (Windows, macOS, Linux).
- **Backend / Core :** Rust (intégré avec `flutter_rust_bridge`).
- **Éditeur de texte :** Code source analysé dynamiquement pour la coloration markdown native et l'intégration de blocs interactifs.

## 🚀 Installation & Lancement

### Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version stable)
- [Rust](https://rustup.rs/) (cargo)
- Si vous êtes sur Windows : Visual Studio 2022 avec les outils de développement C++ (pour compiler Rust et l'application Windows).

### Lancement en mode développeur

1. Installez les dépendances Flutter :
   ```bash
   flutter pub get
   ```
2. Générez le code du bridge Rust-Dart (si nécessaire) :
   ```bash
   flutter_rust_bridge_codegen generate
   ```
3. Lancez l'application (exemple sous Windows) :
   ```bash
   flutter run -d windows
   ```

## 🎨 Philosophie de Design

Muninn n'est pas juste un autre éditeur Markdown. L'accent est mis sur l'expérience utilisateur et les **micro-animations**. Du glissement des onglets jusqu'à l'atterrissage du corbeau (Muninn fait référence à Muninn, l'un des corbeaux d'Odin dans la mythologie nordique, représentant la mémoire), l'application est pensée pour paraître vivante et réactive sous la plume de l'utilisateur.
