# Construction Train

Mod personnel Factorio 2.1.24+, auteur kardagan. Le socle commun se trouve dans ../AGENTS.md.

## Identité et état

- Nom interne : construction-train ; version dans info.json.
- Dépôt Git initialisé sur master le 1er novembre 2026 ; destination GitHub : Kardorio/train-construct.
- Nouveaux modules : pose libre avec R avant construction, voie traversante intégrée, stock enfant et train locomotive — wagon — locomotive ; une machine par force/surface. Les anciens dépôts sur voie nord-sud préparée restent compatibles.
- Graphismes provisoires vanilla ; référence retenue dans docs/concepts/train-depot-v1.png.

## Architecture

- data.lua et prototypes/entities.lua : entités, recette du bâtiment complet et technologie.
- control.lua délègue à scripts/runtime.lua.
- storage.ct : dépôts, index des ghosts, réservations, objets suivis et files progressives.
- scripts/factory.lua : génération idempotente, lien bâtiment-machine, retrait et remboursement.
- scripts/depot.lua : voie intégrée, propriété des rails, coffre enfant, marquage au sol et contrôle du trafic tiers au retrait.
- scripts/registry.lua : vrais ghosts en force technique amie du propriétaire, politiques par force/surface, frontières réelles.
- scripts/worker.lua : conduite native, contact, paiement via scripts/inventory.lua et passe d’accessoires.
- scripts/geometry.lua : bras frontal borné et contact latéral.
- scripts/gui.lua : panneau relatif à l’inventaire natif.

Les unités moteur de tools/probes/ sont des fixtures d’investigation ; elles ne sont pas le runtime du mod. Les tests intégrés doivent appeler le vrai runtime et vérifier les entités réelles et les stocks, pas seulement la disparition des ghosts.

## Vérification

Utiliser ./build.sh lint, ./build.sh test puis python3 tests/visual.py pour les changements qui touchent la GUI ou la récupération. Le test de sauvegarde utilise un serveur temporaire lié à 127.0.0.1 et recharge une vraie sauvegarde en mission. Les tests graphiques utilisent un profil isolé et SDL offscreen.

Les tests et sondes utilisent le moteur headless officiel dans .tools/factorio-headless et refusent Steam. Les commandes natives du joueur sont exercées par --test-save ; la persistance nécessite la passe serveur distincte, car le mode de test natif ne produit pas les autosauvegardes. La vérification visuelle attend un client autonome désigné par FACTORIO_GUI_BIN ; signaler son absence, sans lancer le client Steam.

tests/regressions.py réintroduit les défauts de retrait, de priorité et de retour en copies temporaires pour vérifier les garde-fous. Ne jamais réintroduire ces défauts dans l’arbre du projet pour tester.

Le test legacy-upgrade génère une vraie sauvegarde depuis le commit f14769e, vérifie sa mise à jour et recharge la sauvegarde courante avec identités et contenus exacts conservés. Il nécessite ce commit dans l'historique Git local.

Les journaux sont dans tests/last-engine.log, tests/last-module-*.log, tests/last-legacy-upgrade.log et tests/last-visual.log. La capture docs/prototype-preview.png est historique et représente l'ancien dépôt.
