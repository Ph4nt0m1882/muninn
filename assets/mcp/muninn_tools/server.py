from mcp.server.fastmcp import FastMCP
from ddgs import DDGS
import urllib.request
import json
import bs4
import traceback
import sys
import re
import wikipediaapi
import arxiv
import requests
import sympy
from youtube_transcript_api import YouTubeTranscriptApi

# Initialisation du serveur FastMCP
mcp = FastMCP("Munnin Tools")

@mcp.tool()
def web_search(query: str, max_results: int = 5) -> str:
    """
    Effectue une recherche sur Internet en utilisant DuckDuckGo.
    Utilisez cet outil pour trouver des informations récentes, des faits, ou des réponses à des questions.
    
    Args:
        query: La requête de recherche (mots-clés ou question).
        max_results: Le nombre maximum de résultats à renvoyer (par défaut 5, max 10).
    
    Returns:
        Une chaîne de caractères contenant les résultats de la recherche formatés.
    """
    try:
        results = DDGS().text(query, max_results=min(max_results, 10))
        if not results:
            return "Aucun résultat trouvé pour cette recherche."
            
        formatted_results = []
        for i, res in enumerate(results, 1):
            title = res.get('title', 'Sans titre')
            href = res.get('href', '')
            body = res.get('body', '')
            formatted_results.append(f"{i}. **{title}**\n   {body}\n   Source: {href}")
            
        return "\n\n".join(formatted_results)
    except Exception as e:
        return f"Erreur lors de la recherche: {str(e)}"

@mcp.tool()
def news_search(query: str, max_results: int = 5) -> str:
    """
    Recherche les dernières actualités sur un sujet donné via DuckDuckGo News.
    
    Args:
        query: Le sujet de l'actualité.
        max_results: Le nombre maximum de résultats à renvoyer (par défaut 5, max 10).
        
    Returns:
        Les actualités formatées.
    """
    try:
        results = DDGS().news(query, max_results=min(max_results, 10))
        if not results:
            return "Aucune actualité trouvée pour cette recherche."
            
        formatted_results = []
        for i, res in enumerate(results, 1):
            title = res.get('title', 'Sans titre')
            href = res.get('url', '')
            body = res.get('body', '')
            date = res.get('date', '')
            source = res.get('source', '')
            formatted_results.append(f"{i}. **{title}** ({source} - {date})\n   {body}\n   Lien: {href}")
            
        return "\n\n".join(formatted_results)
    except Exception as e:
        return f"Erreur lors de la recherche d'actualités: {str(e)}"

@mcp.tool()
def read_page(url: str) -> str:
    """
    Lit le contenu textuel d'une page web donnée (scraping de base).
    Utile pour extraire le texte d'un article ou d'un lien fourni dans une recherche.
    
    Args:
        url: L'URL de la page web à lire.
        
    Returns:
        Le texte principal extrait de la page, ou un message d'erreur.
    """
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read()
            soup = bs4.BeautifulSoup(html, 'html.parser')
            
            # Supprimer les balises inutiles
            for script in soup(["script", "style", "nav", "footer", "header"]):
                script.decompose()
                
            text = soup.get_text(separator=' ', strip=True)
            # Limiter la longueur pour ne pas surcharger le contexte de l'IA
            if len(text) > 15000:
                return text[:15000] + "\n\n[...Texte tronqué car trop long...]"
            if text:
                return text
            return "Aucun contenu textuel trouvé sur cette page."
    except Exception as e:
        return f"Erreur lors de la lecture de la page : {str(e)}\n\n{traceback.format_exc()}"

@mcp.tool()
def search_wikipedia(query: str, language: str = "fr") -> str:
    """
    Recherche des informations sur Wikipedia.
    Renvoie le résumé (summary) de la page correspondante ainsi que l'URL complète.
    
    Args:
        query: Le sujet de la recherche.
        language: Le code langue (ex: "fr" pour français, "en" pour anglais).
    
    Returns:
        Un résumé de la page Wikipedia ou un message d'erreur si introuvable.
    """
    try:
        # User-agent requis par Wikipedia
        user_agent = 'Munnin/1.0 (https://github.com/Ph4nt0m1882/munnin) python-requests/2.0'
        wiki_wiki = wikipediaapi.Wikipedia(user_agent, language)
        
        page = wiki_wiki.page(query)
        if not page.exists():
            return f"Aucune page Wikipedia trouvée pour '{query}' en '{language}'."
            
        return f"Titre: {page.title}\nURL: {page.fullurl}\n\nRésumé:\n{page.summary}"
    except Exception as e:
        return f"Erreur lors de la recherche Wikipedia : {str(e)}"

@mcp.tool()
def run_python(code: str) -> str:
    """
    Exécute du code Python localement et renvoie la sortie standard (stdout).
    L'environnement d'exécution possède déjà les bibliothèques suivantes: mcp, duckduckgo_search, beautifulsoup4, requests.
    L'utilisateur peut installer d'autres bibliothèques si nécessaire avec un appel `os.system('uv pip install ...')`.
    
    N'utilisez cet outil que pour des calculs, du traitement de données ou l'exécution de scripts utilitaires.
    
    Args:
        code: Le code Python à exécuter. Vous pouvez utiliser `print()` pour afficher des résultats.
        
    Returns:
        La sortie console générée par l'exécution du code, ou l'erreur s'il y a une exception.
    """
    import io
    from contextlib import redirect_stdout
    
    f = io.StringIO()
    with redirect_stdout(f):
        try:
            # Exécution isolée dans un dictionnaire global vide
            exec(code, {})
        except Exception as e:
            print(f"Erreur d'exécution Python :\n{traceback.format_exc()}")
            
    output = f.getvalue()
    return output if output.strip() else "Exécution terminée sans sortie."

@mcp.tool()
def search_arxiv(query: str, max_results: int = 5) -> str:
    """
    Recherche des articles scientifiques sur arXiv.
    Utilisez cet outil pour trouver des publications académiques en physique, mathématiques, informatique, etc.
    
    Args:
        query: Les mots clés de recherche (ex: "quantum computing", "author:einstein").
        max_results: Le nombre maximum d'articles à renvoyer (par défaut 5, max 10).
    
    Returns:
        Une chaîne formatée contenant les titres, auteurs, dates et résumés des articles.
    """
    try:
        client = arxiv.Client()
        search = arxiv.Search(
            query=query,
            max_results=min(max_results, 10),
            sort_by=arxiv.SortCriterion.Relevance
        )
        
        results = []
        for result in client.results(search):
            authors = ", ".join([author.name for author in result.authors])
            results.append(
                f"Titre: {result.title}\n"
                f"Auteurs: {authors}\n"
                f"Publié le: {result.published.strftime('%Y-%m-%d')}\n"
                f"Lien PDF: {result.pdf_url}\n"
                f"Résumé:\n{result.summary}\n"
                f"{'-'*40}"
            )
            
        if not results:
            return f"Aucun article trouvé sur arXiv pour la requête '{query}'."
            
        return "\n".join(results)
    except Exception as e:
        return f"Erreur lors de la recherche arXiv : {str(e)}"

@mcp.tool()
def get_youtube_transcript(url: str, languages: list[str] = ['fr', 'en']) -> str:
    """
    Récupère la transcription (sous-titres) d'une vidéo YouTube.
    Très utile pour résumer des vidéos sans avoir à les regarder.
    
    Args:
        url: L'URL complète de la vidéo YouTube (ex: https://www.youtube.com/watch?v=...).
        languages: Liste des codes langues préférés (par défaut ['fr', 'en']).
    
    Returns:
        Le texte complet de la transcription de la vidéo.
    """
    try:
        # Extraire l'ID de la vidéo avec une regex
        video_id = None
        
        # Format standard : youtube.com/watch?v=ID
        match = re.search(r'(?:v=|\/)([0-9A-Za-z_-]{11}).*', url)
        if match:
            video_id = match.group(1)
        else:
            return "Erreur : Impossible d'extraire l'ID de la vidéo à partir de l'URL fournie."

        transcript_list = YouTubeTranscriptApi().fetch(video_id, languages=languages)
        
        # Formater la transcription
        formatted_text = []
        for entry in transcript_list:
            # On pourrait inclure le temps, mais pour un LLM, juste le texte suffit généralement
            formatted_text.append(entry.text)
            
        full_text = " ".join(formatted_text)
        
        # Remplacer les sauts de lignes bizarres ou espaces multiples
        full_text = re.sub(r'\s+', ' ', full_text).strip()
        
        if len(full_text) > 30000:
            return full_text[:30000] + "\n\n[...Transcription tronquée car trop longue...]"
            
        return full_text
    except Exception as e:
        return f"Erreur lors de la récupération de la transcription YouTube : {str(e)}"

@mcp.tool()
def search_github(query: str, max_results: int = 5) -> str:
    """
    Recherche des dépôts (repositories) sur GitHub.
    Utile pour trouver des projets open source, des bibliothèques ou du code.
    
    Args:
        query: Les mots clés de recherche (ex: "machine learning language:python").
        max_results: Le nombre maximum de dépôts à renvoyer (par défaut 5, max 10).
    
    Returns:
        Une chaîne formatée avec le nom, la description, les étoiles et l'URL des dépôts.
    """
    try:
        url = "https://api.github.com/search/repositories"
        headers = {
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Munnin/1.0"
        }
        params = {
            "q": query,
            "sort": "stars",
            "order": "desc",
            "per_page": min(max_results, 10)
        }
        
        response = requests.get(url, headers=headers, params=params)
        
        if response.status_code == 403:
            return "Erreur : Limite de requêtes GitHub atteinte. Veuillez réessayer plus tard."
        elif response.status_code != 200:
            return f"Erreur API GitHub : {response.status_code} - {response.text}"
            
        data = response.json()
        items = data.get("items", [])
        
        if not items:
            return f"Aucun dépôt GitHub trouvé pour '{query}'."
            
        results = []
        for repo in items:
            desc = repo.get('description') or "Pas de description"
            results.append(
                f"Dépôt: {repo['full_name']}\n"
                f"Étoiles: ⭐ {repo['stargazers_count']}\n"
                f"Langage: {repo.get('language') or 'Inconnu'}\n"
                f"URL: {repo['html_url']}\n"
                f"Description: {desc}\n"
                f"{'-'*40}"
            )
            
        return "\n".join(results)
    except Exception as e:
        return f"Erreur lors de la recherche GitHub : {str(e)}"

@mcp.tool()
def calculator(expression: str) -> str:
    """
    Calculatrice scientifique et algébrique de niveau Lycée/Université.
    Utilise la bibliothèque SymPy pour évaluer des expressions mathématiques complexes,
    résoudre des équations, calculer des dérivées, intégrales, limites, etc.
    
    Args:
        expression: L'expression mathématique Python/SymPy à évaluer. 
                    Variables courantes (x, y, z, t) pré-définies.
                    Exemples : 
                    - "2 + 2 * 10" (Calcul simple)
                    - "solve(Eq(x**2 - 4, 0), x)" (Résolution d'équation)
                    - "diff(sin(x)*exp(x), x)" (Dérivée)
                    - "integrate(exp(-x**2), (x, -oo, oo))" (Intégrale)
                    - "limit(sin(x)/x, x, 0)" (Limite)
    
    Returns:
        Le résultat de l'évaluation mathématique sous forme de chaîne de caractères.
    """
    try:
        # Préparer l'environnement SymPy avec les variables de base
        from sympy import symbols, Eq, solve, diff, integrate, limit, sin, cos, tan, exp, log, pi, oo, simplify, expand, factor
        
        # Définir des symboles mathématiques courants
        x, y, z, t, a, b, c, n = symbols('x y z t a b c n')
        
        # Dictionnaire des variables globales pour l'évaluation
        eval_globals = {
            'x': x, 'y': y, 'z': z, 't': t, 'a': a, 'b': b, 'c': c, 'n': n,
            'Eq': Eq, 'solve': solve, 'diff': diff, 'integrate': integrate, 'limit': limit,
            'sin': sin, 'cos': cos, 'tan': tan, 'exp': exp, 'log': log, 'pi': pi, 'oo': oo,
            'simplify': simplify, 'expand': expand, 'factor': factor
        }
        
        # Ajouter toutes les fonctions de math / sympy dans le scope au cas où
        import math
        for name in dir(math):
            if not name.startswith('_'):
                eval_globals[name] = getattr(math, name)
                
        # Sympy parse_expr est plus robuste pour transformer les chaînes
        from sympy.parsing.sympy_parser import parse_expr, standard_transformations, implicit_multiplication_application
        
        transformations = standard_transformations + (implicit_multiplication_application,)
        
        # Essayer d'évaluer directement si c'est du Python/Sympy pur
        try:
            result = eval(expression, {"__builtins__": {}}, eval_globals)
        except Exception:
            # Si ça échoue, on essaye de parser comme une expression mathématique (ex: "2x" au lieu de "2*x")
            parsed = parse_expr(expression, local_dict=eval_globals, transformations=transformations)
            result = parsed
            
        return f"Résultat : {str(result)}"
    except Exception as e:
        return f"Erreur de calcul : {str(e)}\n\nAssurez-vous d'utiliser une syntaxe Python/SymPy valide."

@mcp.tool()
def get_current_time(timezone: str = "UTC") -> str:
    """
    Obtient la date et l'heure actuelles, utiles pour connaître le contexte temporel de l'utilisateur.
    
    Args:
        timezone: Le fuseau horaire (ex: "UTC", "Europe/Paris", "America/New_York"). Par défaut "UTC".
        
    Returns:
        La date et l'heure formattées dans le fuseau demandé.
    """
    try:
        from datetime import datetime
        import pytz
        
        try:
            tz = pytz.timezone(timezone)
        except pytz.exceptions.UnknownTimeZoneError:
            return f"Erreur : Fuseau horaire '{timezone}' inconnu. Utilisez un format comme 'Europe/Paris' ou 'UTC'."
            
        now = datetime.now(tz)
        return now.strftime("%A %d %B %Y, %H:%M:%S (%Z)")
    except Exception as e:
        return f"Erreur lors de la récupération de l'heure : {str(e)}"

@mcp.tool()
def read_local_file(file_path: str) -> str:
    """
    Lit le contenu d'un fichier local sur la machine de l'utilisateur.
    Utile pour examiner des logs, du code source, ou des fichiers de configuration.
    
    Args:
        file_path: Le chemin absolu ou relatif du fichier à lire.
        
    Returns:
        Le contenu du fichier sous forme de texte, ou un message d'erreur si le fichier n'existe pas ou n'est pas lisible.
    """
    import os
    try:
        path = os.path.abspath(os.path.expanduser(file_path))
        if not os.path.exists(path):
            return f"Erreur : Le fichier '{path}' n'existe pas."
        if not os.path.isfile(path):
            return f"Erreur : '{path}' n'est pas un fichier."
            
        # Limiter la taille à ~100KB pour éviter de saturer le contexte
        file_size = os.path.getsize(path)
        max_size = 100 * 1024
        
        with open(path, 'r', encoding='utf-8') as f:
            if file_size > max_size:
                content = f.read(max_size)
                return f"⚠️ Fichier trop volumineux ({file_size} octets). Seuls les 100 premiers Ko sont affichés :\n\n{content}\n\n[... CONTENU TRONQUÉ ...]"
            else:
                return f.read()
    except UnicodeDecodeError:
        return f"Erreur : Impossible de lire '{file_path}'. Ce fichier semble être un fichier binaire."
    except Exception as e:
        return f"Erreur lors de la lecture du fichier : {str(e)}"

@mcp.tool()
def execute_command(command: str, cwd: str = None) -> str:
    """
    Exécute une commande système sur la machine locale de l'utilisateur et renvoie sa sortie (stdout/stderr).
    Cet outil est TRÈS puissant mais dangereux. Il permet de compiler du code, lancer des scripts, 
    explorer le système de fichiers (dir, ls), etc.
    
    Args:
        command: La ligne de commande à exécuter (ex: "dir", "python script.py", "git status").
        cwd: (Optionnel) Le répertoire de travail dans lequel exécuter la commande.
        
    Returns:
        La sortie standard (stdout) et la sortie d'erreur (stderr) de la commande.
    """
    import subprocess
    import os
    
    try:
        # Vérification du répertoire de travail
        if cwd:
            cwd = os.path.abspath(os.path.expanduser(cwd))
            if not os.path.exists(cwd) or not os.path.isdir(cwd):
                return f"Erreur : Le répertoire de travail '{cwd}' n'existe pas ou n'est pas un dossier."
                
        # Exécution de la commande
        # shell=True est nécessaire pour que des commandes comme 'dir' ou 'echo' fonctionnent sur Windows/Linux
        process = subprocess.run(
            command,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=60 # Timeout de sécurité de 60 secondes
        )
        
        output = ""
        if process.stdout:
            output += f"--- STDOUT ---\n{process.stdout}\n"
        if process.stderr:
            output += f"--- STDERR ---\n{process.stderr}\n"
            
        if not output:
            output = "La commande s'est exécutée avec succès mais n'a renvoyé aucune sortie."
            
        return f"Code de retour : {process.returncode}\n\n{output}"
        
    except subprocess.TimeoutExpired:
        return f"Erreur : La commande '{command}' a expiré après 60 secondes d'exécution."
    except Exception as e:
        return f"Erreur lors de l'exécution de la commande : {str(e)}"

if __name__ == "__main__":
    mcp.run()
