# Captures d'écran du manuel ANOVA

Le script `captures.py` régénère les captures du dossier `images/` en pilotant
l'application comme le ferait un étudiant. Chaque capture part d'une page
fraîchement chargée. Au démarrage, l'application simule l'exemple de référence
(réglages par défaut, graine 2026) : les chiffres visibles sont donc ceux que
cite le manuel.

## Installation (une seule fois)

```bash
pip install playwright pillow
python -m playwright install chromium
```

## Utilisation

Depuis la racine du manuel :

```bash
# Lancer l'application et tout régénérer
python captures/captures.py --app chemin/vers/ANOVA

# Utiliser une instance déjà ouverte
python captures/captures.py --url http://127.0.0.1:8765

# Un seul chapitre (00 = préface, 01 à 08), ou une seule image
python captures/captures.py --app chemin/vers/ANOVA --chapitre 02
python captures/captures.py --app chemin/vers/ANOVA --fichier chap2-stats.png
```

Les noms des images suivent la numérotation des chapitres : `chap3-…` pour le
chapitre 3, et ainsi de suite.

## L'exemple de référence

Sauf indication contraire, les captures utilisent les réglages par défaut de
l'application : 5 groupes de 10, moyennes 80 à 120 par pas de 10, σ = 15,
loi normale, graine **2026**. La fonction `simuler_anova()` de `_common.R`
reproduit exactement ces données pour les figures produites en R (les calculs
viennent de `_moteur.R`, copie des fonctions de `global.R`). Si la simulation
ou les calculs de l'application changent, il faut modifier les deux.

Exceptions :

- `chap2-asymetrie.png` : 3 groupes de 40, moyennes 60; 100; 140, σ = 40,
  forme log-normale, graine 2026.
- Jeu « hétérogène » (`chap4-welch`, `chap6-recommandation`,
  `chap6-normalite-hetero`, `chap6-homogeneite`) : 3 groupes, moyennes
  égales à 100, n = 30, 20, 10, σ = 5, 12, 25, graine 51.
- Jeu « asymétrique » (`chap4-kw`, `chap4-bootstrap`,
  `chap6-graphiques-asym`) : 3 groupes de 15, moyennes 100; 100; 130,
  σ = 60, forme log-normale, graine 174.
- `chap5-tendance.png` : variable indépendante déclarée quantitative.
- Chapitre 8 (`chap8-…`) : fichier `donnees/insecticides.csv` importé;
  `chap8-racine-…` avec la transformation racine carrée.
- Les captures de l'onglet Expérimentation (`chap5-risque-global`,
  `chap7-…`) et `chap4-bootstrap` reposent sur des tirages aléatoires : leurs
  chiffres varient légèrement d'une capture à l'autre. Le manuel n'en cite
  que des ordres de grandeur.

## Remarques

- Les captures sont faites à 1 440 × 1 000 pixels (certaines cartes de
  résultats dans une fenêtre plus étroite ou plus large), avec un facteur 2 :
  images nettes à l'impression.
- Sous Linux, lancez R avec une locale UTF-8 (`LANG=C.UTF-8`), sinon l'app ne
  se charge pas et les figures R affichent `<U+00E9>` au lieu des accents.
- Les formules (onglet Introduction, panneau de décomposition de la variance)
  sont dessinées par MathJax, chargé depuis Internet. Hors ligne, l'option
  `--mathjax dossier` pointe vers une copie locale de MathJax 2
  (sous Debian/Ubuntu : `/usr/share/javascript/mathjax`).
