# Template

Here is the standard template you must follow for `server_content`:

```python
from mcp.server.fastmcp import FastMCP

# Créez une instance de FastMCP avec le nom de votre serveur
mcp = FastMCP("nom_du_serveur")

# Utilisez le décorateur @mcp.tool() pour exposer vos fonctions
@mcp.tool()
def ma_fonction(param1: str) -> str:
    """
    Description claire de ce que fait la fonction.
    C'est cette description que l'IA lira pour comprendre l'outil.
    
    Args:
        param1: Description du paramètre
        
    Returns:
        Ce que retourne la fonction (toujours sous forme de chaîne de caractères)
    """
    try:
        # Implémentation
        return f"Résultat pour {param1}"
    except Exception as e:
        return f"Erreur : {str(e)}"

# Le point d'entrée est géré automatiquement par munnin,
# ne rajoutez pas de if __name__ == "__main__": mcp.run()
```

Here is the standard template for `requirements_content`:

```text
mcp
# Ajoutez vos autres dépendances ici (ex: requests, beautifulsoup4)
```
