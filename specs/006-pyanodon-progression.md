# 006 — Fabrication et recherche avec Pyanodon

**Statut** : qualifié dans le moteur le 5 novembre 2026 ; essai en partie Pyanodon par Geoffrey restant à effectuer.

## Problème et solution

Le coût de recherche vanilla du dépôt conserve le pack vert, alors que Pyanodon réorganise le palier ferroviaire. Le dépôt doit suivre les packs, quantités et durée de la recherche ferroviaire automatisée réellement chargée. Il conserve cette recherche en prérequis.

Recette Py retenue par Geoffrey : 2 locomotives, 1 wagon, 4 coffres en acier, 40 plaques d'acier, 40 pièces mécaniques, 15 circuits imprimés et 15 rails. Les pièces mécaniques `small-parts-01` proviennent de Petroleum Handling ; sans ce module, les 40 engrenages sont conservés. Les circuits imprimés de Py High Tech portent l'identifiant `electronic-circuit` ; les profils Py sans ce module utilisent donc 15 circuits électroniques de base. Les coûts des locomotives et du wagon restent ceux du pack Py. Le prérequis d'entrepôt ajouté initialement est supprimé, car aucun entrepôt ne figure dans cette recette.

## Critères d'acceptation

- [x] **AC1** Sans Py, recette, prérequis et coût de recherche vanilla restent identiques.
- [x] **AC2** Avec Py, les packs, quantités et durée de recherche correspondent à la recherche ferroviaire automatisée après les modifications du pack ; aucun pack inexistant n'est référencé.
- [x] **AC3** Les quatre coffres en acier sont conservés, les pièces mécaniques ne sont utilisées qu'avec Petroleum Handling et la recette Py demande 15 circuits. Aucun prérequis d'entrepôt n'est ajouté.
- [x] **AC4** La recette s'active après recherche et peut être réellement fabriquée avec ses ingrédients ; elle produit l'objet du dépôt.
- [x] **AC5** Les profils Py Coal seul, Py Industry seul et pack Py complet installé chargent dans le moteur officiel. La version bêta porte les mêmes adaptations.
- [x] **AC6** Stocks, véhicules et sauvegardes existants ne sont pas recréés par cette adaptation de prototypes.

## Phase unique

**Couvre** : AC1 à AC6.

**Impact sur les données** : recette et technologie existantes, dépendances optionnelles et ordre de chargement. Aucun nouvel inventaire ni état de fonctionnement.

**Définition de terminé** : lint et tests vanilla verts, chargement moteur des profils Py isolés, contrôle des prototypes finaux, recherche et fabrication natives dans le profil complet, ZIP bêta régénéré. Les profils du joueur et ses sauvegardes restent intacts ; aucun client Steam n'est utilisé.

## Vérifications effectuées

`./build.sh test-py` charge les dernières archives locales dans quatre profils temporaires : vanilla, Py Coal Processing, Py Industry et Py complet. Les quatre passent avec le paquet bêta. Chaque profil contrôle les ingrédients et produits finaux, les prérequis et le coût de recherche, puis la sélection native de la recherche, le déblocage et une fabrication native avec consommation exacte des ingrédients.

`./build.sh lint` et `./build.sh test` réussissent également, avec sauvegardes rechargées et migration depuis le prototype historique conservant les identités et stocks. Les tests de packaging vérifient la présence de l'adaptation Py dans les deux variantes et la conservation des sources locales.
