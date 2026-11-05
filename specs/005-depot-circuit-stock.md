# 005 — Lecture du stock du dépôt par réseau logique

**Statut** : implémenté et qualifié moteur le 5 novembre 2026 ; rendu des fils à vérifier en sandbox.

## Problème et solution

Le dépôt doit pouvoir communiquer son stock aux circuits pour automatiser son approvisionnement. Il accepte les fils rouges et verts dans ses quatre orientations et transmet les quantités réellement présentes dans son inventaire, avec leur qualité. Le wagon et les locomotives ne sont pas inclus. Les signaux reçus ne commandent ni démarrage, ni pause, ni rappel.

## Critères d'acceptation

- [x] **AC1** Le joueur peut raccorder directement le bâtiment aux réseaux rouge et vert, dans les quatre orientations.
- [x] **AC2** Les réseaux lisent les quantités exactes du stock, qualités comprises, et reflètent les insertions et retraits réels.
- [x] **AC3** Les contenus du wagon et des locomotives n'apparaissent pas dans cette lecture ; les signaux reçus ne pilotent pas le train.
- [x] **AC4** La lecture utilise l'inventaire existant ; chargement, récupération et contenus sont conservés.
- [x] **AC5** Une sauvegarde rechargée conserve les connexions et le réglage natif de lecture. Les anciens dépôts restent compatibles.

## Phase unique — Raccordement natif

**Couvre** : AC1 à AC5.

**Impact sur les données** : connecteurs du bâtiment et configuration native de lecture ; aucun nouvel inventaire ni transfert de contenu.

**Définition de terminé** : vrais réseaux rouge et vert dans le moteur officiel, contrôle des quantités et qualités avant et après modification et rechargement, suite moteur et lint réussis. Le rendu des fils reste à vérifier en sandbox si le client graphique autonome est absent.

## Qualification

Les quatre scénarios du module utilisent de vrais poteaux et réseaux rouge et vert distincts, avec vérification de portée native des fils. Le cuivre normal et rare ajouté au dépôt apparaît dans les bonnes quantités puis suit les retraits ; du cuivre supplémentaire dans le wagon et du charbon dans les locomotives ne sont pas additionnés. Le réglage natif de lecture désactivé reste désactivé pendant la mission et après rechargement. La revue confirme l'absence de chemin de commande du train depuis les signaux reçus. La suite moteur et le lint ont réussi ; l'affichage graphique automatique est indisponible faute de client autonome.
