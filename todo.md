# Munnin - Liste des choses à faire (To-Do)

## 🤖 Intelligence Artificielle (RAG & Agent)
- [x] **Historique des Conversations** : Implémenter la sauvegarde et l'interface pour parcourir, reprendre et gérer les anciennes sessions de chat.
- [ ] **Capacités Agentiques (Tool Calling)** : Donner à l'IA la capacité d'agir sur l'application via des outils :
  - Ouvrir une page du wiki spécifique sur demande.
  - Modifier le thème de l'application.
  - Modifier des paramètres internes si l'utilisateur le demande.
- [ ] **Nouvelles Commandes Éditeur (Slash Commands)** :
  - `/create_rules` : Générer ou appliquer des règles personnalisées.
  - `/create_commandes` : Aide à la création de raccourcis ou de macros.
  - `/create_mcp` : Configuration de connexions externes (Model Context Protocol).

## 🕸️ Visualisation & Navigation
- [ ] **Vue Graphe de Connaissances** : Implémenter la toile interactive reliant les notes entre elles.
- [ ] **Filtres du Graphe** : Ajouter un système permettant de filtrer les nœuds du graphe en fonction des `#tags` présents dans les fichiers Markdown.
- [ ] **Spotlight Intelligent (Ctrl+Shift+F)** : Afficher les fichiers récemment ouverts/modifiés par défaut lors de l'ouverture de la barre de recherche globale.

## 📅 Modules Dynamiques
- [ ] **Vue Calendrier (Module Journal)** : Ajouter un widget calendrier dans la barre latérale pour visualiser les notes journalières existantes et créer celles manquantes d'un simple clic sur une date.

## 🔄 Import / Export
- [ ] **Fonction d'Importation** :
  - Depuis **OneNote**.
  - Depuis **ZIM Desktop Wiki**.
  - *Option :* Importer comme un tout nouveau Wiki ou comme un sous-dossier d'un Wiki existant.
- [ ] **Fonction d'Exportation** : Possibilité d'exporter une note (ou un dossier complet) en PDF ou HTML pour faciliter le partage.
