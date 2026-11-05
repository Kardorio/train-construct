# 004 — Choisir les éléments construits par le train

**Statut** : implémenté, qualifié moteur et validé par Geoffrey en sandbox le 5 novembre 2026.
**Demandeur** : Geoffrey.
**Date** : 2026-11-05.

## Problème

Un chantier peut ne demander que des rails, ou des rails et des signaux ordinaires. Les objectifs de chargement actuels définissent des quantités à emporter ; ils ne permettent pas d'interdire au train de construire une catégorie. Un bloc sans signaux chaînés ne doit pas attendre leur approvisionnement.

## Solution proposée

Le panneau du dépôt propose quatre cases indépendantes : rails, signaux ferroviaires, signaux ferroviaires chaînés et arrêts de train. Le joueur peut sélectionner une ou plusieurs catégories. Le choix porte sur les catégories construites, distinctement des quantités à charger.

Pour une catégorie désactivée, le train ne charge plus de nouveaux objets et ne les attend plus pour partir. La quantité configurée est conservée pour une réactivation ultérieure ; les objets déjà embarqués restent dans le wagon. Les ghosts exclus ne sont ni supprimés ni considérés comme du travail restant pour le train.

Les catégories exclues restent disponibles pour les robots, même quand le dépôt réserve ses propres travaux à l'échelle de la planète. Les anciennes sauvegardes démarrent avec les quatre catégories autorisées pour préserver leur comportement.

## Critères d'acceptation

- [x] **AC1** Chaque dépôt permet d'activer indépendamment les quatre catégories ; le réglage persiste après sauvegarde et rechargement.
- [x] **AC2** En mode rails seuls, seuls les ghosts de rails compatibles sont construits et payés ; signaux et arrêts restent intacts.
- [x] **AC3** En mode rails et signaux ordinaires, le train ne construit aucun signal chaîné ni arrêt et n'attend pas leurs matériaux pour partir.
- [x] **AC4** En mode accessoires seuls, le train utilise les rails réels accessibles sans construire de rails exclus. Les vérifications existantes de contact, de circulation et de retour restent obligatoires ; aucun accessoire exclu n'est construit pour contourner un blocage.
- [x] **AC5** Une catégorie désactivée ne crée plus de demande de chargement et sa quantité configurée est restaurée à la réactivation. Les objets déjà embarqués ne sont ni détruits ni dupliqués.
- [x] **AC6** Un changement pendant une mission libère les réservations de travail devenues incompatibles et réévalue la destination sans modifier directement la position ou la vitesse du train.
- [x] **AC7** Si aucune catégorie n'est activée, le train n'accepte aucun chantier et le panneau explique cet état.
- [x] **AC8** Après mise à jour, une sauvegarde sans filtres conserve les quatre catégories actives et ses contenus.
- [x] **AC9** Les ghosts exclus restent dans la force du joueur ou y sont restitués progressivement ; le mod ne commande pas l'annulation des actions des robots.

## Phase unique — Filtres et politique de réservation

**Travail** : réglages du panneau, choix des travaux, chargement, réservations et compatibilité des sauvegardes.

**Couvre** : AC1 à AC9.

**Impact sur les données** : ajout des catégories autorisées à chaque dépôt, initialisées avec toutes les catégories actives sur les sauvegardes existantes.

**Définition de terminé** : tests du vrai runtime avec chantiers mixtes, contrôle des entités construites et des stocks, changement de filtre pendant une mission, réservation des robots et sauvegarde rechargée. Lint et suite moteur réussis ; recette du panneau à faire en sandbox si aucun client graphique autonome n'est disponible.

## Hors périmètre

La connexion au réseau logique est traitée dans la spécification 005. Aucun filtrage par position, blueprint ou qualité, ni extension aux autres bâtiments de Factorio.

## Décisions validées

- Les robots peuvent construire les catégories exclues du train.
- Aucun pilotage du train par le réseau logique dans ce lot.

## Qualification

Le scénario moteur `filters` construit 52 rails, puis un signal ordinaire, puis un arrêt sur une voie existante. Le signal chaîné et le rail supplémentaire exclus restent de vrais ghosts dans la force du joueur. Les comptes exacts des stocks sont contrôlés, ainsi que le changement pendant la marche et le rechargement d'une vraie sauvegarde. Les deux mutations `filters-reservation` et `filters-load` sont rejetées par les assertions attendues. Les scénarios orientés vérifient les cases natives et la reconstruction d'un panneau d'ancienne structure. La suite complète et le lint ont réussi ; le client graphique autonome est absent, aucun client Steam n'est lancé.
