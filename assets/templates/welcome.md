---
title: "welcome"
created: "2024-01-01"
tags: ["tutoriel", "systeme"]
status: "system"
description: "Fichier système tutoriel de Munnin. Ce fichier n'appartient pas à l'utilisateur, c'est un guide généré automatiquement par l'application pour expliquer le fonctionnement du Markdown enrichi."
---

# Bienvenue dans Munnin ! 🐦‍⬛

Votre nouvelle base de connaissances est prête. Munnin n'est pas un simple éditeur Markdown, c'est un environnement **interactif** et **enrichi**.

Ce document est une **vitrine exhaustive** de tout ce que vous pouvez accomplir ici. Que vous soyez un parfait débutant en Markdown ou un expert cherchant à utiliser les fonctionnalités exclusives de Munnin, ce guide vous expliquera la syntaxe dans les moindres détails.

---

## 1. La syntaxe de base (Le B.A.-BA)

Le Markdown permet de mettre en forme du texte très facilement sans avoir à cliquer sur des boutons, juste avec quelques caractères spéciaux.

### 1.1. Les Titres
Les titres sont créés en utilisant des `#` (dièses) au début de la ligne, suivis d'un espace. Le nombre de `#` indique le niveau du titre (de 1 à 6).

```markdown
# Titre de niveau 1 (Le plus grand)
## Titre de niveau 2
### Titre de niveau 3
#### Titre de niveau 4
##### Titre de niveau 5
###### Titre de niveau 6 (Le plus petit)
```

<details> <summary>💡 Astuce (Titres alternatifs)</summary>

Vous pouvez aussi créer des titres de niveau 1 et 2 en "soulignant" le texte :
```markdown
Titre de Niveau 1
=================

Titre de Niveau 2
-----------------
```
</details>

### 1.2. Mise en forme du texte
Mettez votre texte en valeur en l'entourant de symboles :

```markdown
**Texte en gras** (avec deux astérisques)
*Texte en italique* (avec un seul astérisque)
~~Texte barré~~ (avec deux tildes)
***Gras et italique*** (en combinant trois astérisques)
```

**Rendu :**
**Texte en gras** | *Texte en italique* | ~~Texte barré~~ | ***Gras et italique***

### 1.3. Lignes de séparation
Pour tracer une belle ligne horizontale, écrivez simplement trois tirets ou trois astérisques sur une ligne vide :

```markdown
---
***
```

---

## 2. Organisation (Listes, Tableaux, Citations)

### 2.1. Les Listes
**Listes à puces (non ordonnées) :** Utilisez un tiret `-`, un astérisque `*` ou un plus `+`.
**Listes numérotées :** Utilisez des chiffres suivis d'un point `1.`, `2.`.

```markdown
- Faire les courses
  - Acheter du pain (ajoutez des espaces au début pour imbriquer)
  - Acheter du lait
1. Préparer le petit-déjeuner
2. Manger
```

### 2.2. Les Tableaux
Créez des tableaux en utilisant des barres verticales `|` pour délimiter les colonnes, et des tirets `-` pour séparer l'en-tête du contenu. Les deux-points `:` permettent d'aligner le texte !

```markdown
| Colonne Alignée à Gauche | Colonne Centrée | Colonne Alignée à Droite |
| :--- | :---: | ---: |
| Ligne 1 | A | 100 |
| Ligne 2 | B | 200 |
```

**Rendu :**
| Colonne Alignée à Gauche | Colonne Centrée | Colonne Alignée à Droite |
| :--- | :---: | ---: |
| Ligne 1 | A | 100 |
| Ligne 2 | B | 200 |

### 2.3. Les Citations (Blockquotes)
Idéal pour citer quelqu'un ou mettre un paragraphe en retrait. Utilisez le chevron `>`.

```markdown
> "L'imagination est plus importante que le savoir."
> - Albert Einstein
>> Et vous pouvez même imbriquer des citations !
```

---

## 3. Les Super-Pouvoirs de Munnin ✨ (Exclusivités)

Munnin modifie et améliore le comportement standard du Markdown pour le rendre interactif.

### 3.1. Listes de tâches interactives (Checkboxes)
Dans un Markdown classique, on écrit une tâche comme ceci : `- [ ] Tâche à faire`. 
Dans Munnin, vos listes de tâches ont **4 états différents** et peuvent être modifiées directement à la souris depuis la vue de lecture ! Le fichier est sauvegardé silencieusement.

```markdown
- [ ] **Tâche vide** : Essayez de faire un clic gauche !
- [*] **Tâche en cours** : (Obtenu via un clic gauche)
- [v] **Tâche validée** : (Obtenu via un double-clic)
- [x] **Tâche annulée** : (Obtenu via un clic droit)
```

**Rendu interactif (essayez de cliquer !) :**
- [ ] Tâche vide
- [*] Tâche en cours
- [v] Tâche validée
- [x] Tâche annulée

### 3.2. Blocs de Code et Mode Édition `{edit}`
Pour insérer du code, on utilise trois backticks `` ` ``. Munnin détecte le langage pour la coloration syntaxique.
**Nouveauté :** Ajoutez `{edit}` à côté du nom du langage pour transformer le bloc de code en une zone de texte modifiable !

```markdown
```python
# Un bloc de code classique
print("Bonjour le monde")
```
```

**Bloc éditable :**
```markdown
```python {edit}
# Ce bloc pourra être modifié directement dans le rendu !
def hello():
    pass
```
```

### 3.3. Admonitions et Alertes GitHub
Munnin supporte les blocs d'alerte. Écrivez une citation `>` suivie de `[!TYPE]`.

```markdown
> [!NOTE]
> Ceci est une note standard.

> [!TIP]
> Une astuce bien pratique !

> [!WARNING]
> Attention à ce détail.

> [!CAUTION]
> Une action dangereuse.
```

**Rendu :**
> [!NOTE]
> Ceci est une note standard.

> [!TIP]
> Une astuce bien pratique !

### 3.4. Admonitions Personnalisées 🎨
Vous n'êtes pas limité aux alertes standards ! Vous pouvez créer vos propres alertes avec la syntaxe : `> [!{icone}{Titre}{couleur}]`.
*Les couleurs disponibles sont l'anglais basique (red, blue, green, purple, orange, etc.).*

```markdown
> [!{lucide-flame}{Urgence Absolue}{red}]
> Le serveur est en feu !
```

**Rendu :**
> [!{lucide-flame}{Urgence Absolue}{red}]
> Le serveur est en feu !

### 3.5. Liens Wiki (WikiLinks)
Pour lier vos notes entre elles, plus besoin des longs chemins absolus. Utilisez la syntaxe `[[Lien]]` !

```markdown
- Lien simple : [[Nom_du_fichier]]
- Lien avec texte personnalisé (Alias) : [[Nom_du_fichier|Texte affiché]]
- Lien vers un chapitre précis : [[Nom_du_fichier(Titre du chapitre)]]
```

### 3.6. Gestionnaire d'Images Local (Double Bang `!!`)
Munnin est conçu pour être un wiki 100% portable et déconnecté. Si vous utilisez deux points d'exclamation `!![alt](url)` avec un lien Web ou un chemin absolu vers votre disque dur, **Munnin va automatiquement télécharger l'image** !

L'image sera copiée dans un dossier caché `.assets/` juste à côté de votre document actuel, et le lien se mettra à jour tout seul pour pointer vers cette image locale de façon relative. Ainsi, votre wiki reste parfaitement transportable sans jamais casser les liens !

```markdown
!![Logo Dart](https://raw.githubusercontent.com/dart-lang/logos/main/logos/dart/logo.png)
```
*(Basculez en mode lecture pour voir Munnin télécharger et afficher ce logo localement)*

### 3.7. Notes de Bas de Page (Footnotes)
Ajoutez des références dans votre texte en utilisant `[^1]`, puis définissez-les à la fin du document.

```markdown
Voici une affirmation très intéressante.[^1]

[^1]: Et voici la source ou l'explication détaillée en bas de page.
```

---

## 4. Sélecteur d'Icônes (Icon Picker)
Pour vous aider à personnaliser vos documents (et vos Admonitions Personnalisées), Munnin intègre un sélecteur de milliers d'icônes (Lucide et Simple Icons).
- Cliquez sur l'icône **😃** dans la barre d'outils au-dessus de l'éditeur ou utilisez `Ctrl + Maj + I`.
- Double-cliquez sur une icône pour l'insérer !

---
*Maintenant, c'est à vous de jouer ! Explorez, écrivez et laissez Munnin vous aider à bâtir votre cerveau numérique.*
