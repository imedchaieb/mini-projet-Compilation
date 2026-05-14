# Mini-projet — Interpréteur Flex/Bison

## Fonctionnalités ajoutées
- opérateurs de comparaison : `== != < > <= >=`
- opérateurs logiques : `&& || !`
- tableaux simples : lecture et écriture avec `tab[expr]`
- boucle `tantque (condition) alors ... fin`

## Compilation sous MSYS2
Dans le terminal MSYS2 MinGW64 :

```bash
make
./interpreteur.exe
```

Ou avec un fichier d'entrée :

```bash
./interpreteur.exe tests/test_while.txt
```

## Remarques
- Les variables non initialisées valent `0`.
- Les comparaisons et opérateurs logiques renvoient `0` ou `1`.
- Les tableaux s'étendent automatiquement si un indice plus grand est utilisé.

## Erreurs:
    1. lex.l:
        - Erreur mémoire
        - Caractére non reconnu a la ligne %d
    2. interpreteur.y:
        - Table des symboles pleines
        - Allocation mémoire impossible
        - Ligne %d indice de table négative
        - Erreur syntaxique ligne %d
        
