# Construction Train

Mod personnel Factorio 2.1.24+, auteur kardagan. Le socle commun se trouve dans ../AGENTS.md.

## Identité et état

- Nom interne : construction-train ; version dans info.json.
- Dépôt Git initialisé sur master le 1er novembre 2026 ; destination GitHub : Kardorio/train-construct.
- Nouveaux modules : pose libre avec R avant construction, voie traversante intégrée, stock enfant et train locomotive — wagon — locomotive ; une machine par force/surface. Les anciens dépôts sur voie nord-sud préparée restent compatibles.
- Atelier en sprites 2D, sol métallique sous les rails et stock intégré accessible par bras le long de l'atelier ; véhicules vanilla provisoires. Référence retenue dans docs/concepts/train-depot-v1.png.

## Architecture

- data.lua et prototypes/entities.lua : entités, recette du bâtiment complet et technologie.
- data-final-fixes.lua et prototypes/pyanodon.lua : recette adaptée aux modules Py présents et coût de recherche aligné sur le ferroviaire après pypostprocessing. Sans Py, aucun changement.
- prototypes/depot-graphics.lua et depot-sprite-layout.lua : sprites du module, échelles et rectangles natifs ; métadonnées générées par tools/art/prepare_sprites.py sans réécrire les PNG.
- control.lua délègue à scripts/runtime.lua.
- storage.ct : dépôts, index des ghosts, réservations, objets suivis et files progressives.
- scripts/factory.lua : génération idempotente, lien bâtiment-machine, retrait et remboursement.
- scripts/depot.lua : voie intégrée, propriété des rails, stock enfant invisible, protections de collision latérales, nettoyage des anciens décors et contrôle du trafic tiers au retrait.
- scripts/registry.lua : vrais ghosts en force technique amie du propriétaire, politiques par force/surface, frontières réelles.
- scripts/worker.lua : conduite native, contact, paiement via scripts/inventory.lua et passe d’accessoires.
- scripts/geometry.lua : bras frontal borné et contact latéral.
- scripts/gui.lua : panneau relatif à l’inventaire natif.
- scripts/categories.lua : catégories autorisées, indépendantes des quantités cibles ; les ghosts exclus restent disponibles pour les robots.
- scripts/circuit.lua : première activation de la lecture native du stock du dépôt ; réglage persistant sans commande du train.

Les unités moteur de tools/probes/ sont des fixtures d’investigation ; elles ne sont pas le runtime du mod. Les tests intégrés doivent appeler le vrai runtime et vérifier les entités réelles et les stocks, pas seulement la disparition des ghosts.

## Vérification

Utiliser ./build.sh lint, ./build.sh test puis python3 tests/visual.py pour les changements qui touchent la GUI ou la récupération. Le test de sauvegarde utilise un serveur temporaire lié à 127.0.0.1 et recharge une vraie sauvegarde en mission. Les tests graphiques utilisent un profil isolé et SDL offscreen.

./build.sh test-py utilise les dernières archives Py installées dans quatre profils isolés, dont un sans Py. Il contrôle les prototypes finaux, le déblocage après recherche et la fabrication native avec consommation exacte des ingrédients dans le paquet bêta. Les journaux sont tests/last-py-*.log.

Les tests et sondes utilisent le moteur headless officiel dans .tools/factorio-headless et refusent Steam. Les commandes natives du joueur sont exercées par --test-save ; la persistance nécessite la passe serveur distincte, car le mode de test natif ne produit pas les autosauvegardes. La vérification visuelle attend un client autonome désigné par FACTORIO_GUI_BIN ; signaler son absence, sans lancer le client Steam.

tests/regressions.py réintroduit les défauts de retrait, de priorité et de retour en copies temporaires pour vérifier les garde-fous. Ne jamais réintroduire ces défauts dans l’arbre du projet pour tester.

Le test legacy-upgrade génère une vraie sauvegarde depuis le commit f14769e, vérifie sa mise à jour et recharge la sauvegarde courante avec identités et contenus exacts conservés. Il nécessite ce commit dans l'historique Git local.

./build.sh sprites-check vérifie les quatre images, le dégagement de la voie, la continuité du bâtiment et leur présence inchangée dans l'archive. ./build.sh sprites-preview produit une recomposition de contrôle hors jeu ; ce n'est pas une capture Factorio. Les PNG du bâtiment sont issus de la référence validée, le modèle procédural sous tools/art est un essai écarté.

Les journaux sont dans tests/last-engine.log, tests/last-module-*.log, tests/last-legacy-upgrade.log et tests/last-visual.log. La capture docs/prototype-preview.png est historique et représente l'ancien dépôt.
