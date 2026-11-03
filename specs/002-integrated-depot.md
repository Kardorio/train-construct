# 002 — Dépôt avec voie traversante intégrée

**Statut** : implémenté et qualifié dans le moteur le 3 novembre 2026 ; contrôle graphique et recette sandbox du nouveau module à effectuer.
**Demandé par** : Geoffrey.
**Date** : 2026-11-02.

## Problème

Le prototype impose une voie préparée puis la pose du dépôt à côté. Geoffrey souhaite poser un bâtiment autonome qui fournit sa propre voie, comme Train Foundry, et raccorder lui-même son réseau aux deux extrémités.

## Solution

Le bâtiment génère sa voie interne traversante, son quai de ravitaillement et son unique train locomotive — wagon — locomotive. Il peut être posé sur un terrain libre sans voie existante. Un raccord dépasse à chaque extrémité ; le joueur construit les liaisons avec son réseau dans les deux sens. Aucune recherche d'une voie voisine ne détermine le placement.

Le principe est repris de Train Foundry : rails internes solidaires du bâtiment, extrémités sélectionnables pour prolonger la voie. Le dépôt ne construit pas de raccordement extérieur automatiquement.

## Périmètre

- Bâtiment, voie interne, quai, stock et train comme un ensemble solidaire.
- Entrée et sortie aux extrémités d'une même voie traversante utilisable dans les deux sens.
- Pose sans rail préparé ; validation de l'espace réellement nécessaire et refus propre sur obstacle.
- Protection des rails internes contre le minage ou la déconstruction individuels.
- Retrait conservant les contenus, les occupants et les rails du joueur.
- Compatibilité avec les dépôts existants, sans suppression ni régénération de leur train.
- Limite d'une machine par force et surface conservée.
- Rotation du module avec R avant la pose ; rotation bloquée après génération des composants.

## Hors périmètre

Création de raccords extérieurs, génération de réseau, terrassement, voies diagonales à l'intérieur, rails surélevés, flotte de plusieurs trains, cendres Py et graphismes définitifs.

## Critères d'acceptation

- [x] **AC1** Sur un terrain libre sans rail, la pose génère exactement la voie interne, un quai connecté et un train de trois véhicules rattaché au bâtiment.
- [x] **AC2** Le moteur expose un prolongement réel à chaque extrémité sélectionnable ; les commandes natives du joueur posent les raccords. Le train rejoint le réseau et revient par chacun des deux côtés. Le geste graphique du planificateur reste à vérifier en sandbox.
- [x] **AC3** Un obstacle ou une voie occupée provoque un refus complet avec remboursement dans la qualité du bâtiment, sans rail ni véhicule partiel restant.
- [x] **AC4** Les rails internes ne fournissent pas de rails gratuits par minage ; le retrait détruit uniquement les rails créés par le bâtiment et préserve les raccordements appartenant au joueur. Un véhicule tiers sur la voie diffère le retrait.
- [x] **AC5** Le chargement, la pose en roulant, la rupture de stock, le retour et la reprise fonctionnent après une vraie sauvegarde rechargée, avec comptage exact des matériaux.
- [x] **AC6** Une vraie sauvegarde créée par le commit précédent garde son dépôt en pause, ses véhicules, ses voies et ses contenus sans génération d'une seconde machine ni voie nouvelle. Une sauvegarde courante est ensuite rechargée avec les mêmes assertions.
- [x] **AC7** Les indications françaises et anglaises expliquent la pose libre et le raccordement manuel des deux extrémités.
- [x] **AC8** Le placement natif permet les quatre orientations cardinales avant la pose ; la voie, le quai et le stock suivent l'orientation, et le module posé ne tourne plus indépendamment de ses composants.

## Phase unique — Module de dépôt autonome

**Couvre** : AC1 à AC8.

**Impact sur les données** : suivi des rails créés et des composants du module ; distinction entre anciens dépôts et nouveaux modules ; aucune appropriation silencieuse des rails du joueur.

**Définition de terminé** : suite moteur sans Steam, pose sur terrain vierge, raccords réels dans les deux sens, retour/ravitaillement, retrait et reprise après sauvegarde vérifiés ; revue sans défaut restant. Le contrôle graphique attend un client autonome et n'autorise aucun repli vers Steam.

**Preuves du 3 novembre 2026** : `./build.sh lint`, `./build.sh test` et `./build.sh test --scenario legacy-upgrade` réussissent. Les quatre orientations terminent les missions, les deux essais de panne et les rechargements ; huit mutations du module sont rejetées. Les revues runtime et tests/documentation ne relèvent aucun défaut restant. `python3 tests/visual.py` s'arrête explicitement faute de client graphique autonome : aucune capture ni interaction graphique du nouveau module n'est déclarée validée.

## Questions ouvertes

Aucune. Geoffrey confirme la rotation avant la pose. Le coffre provisoire actuel reste le prototype des anciens dépôts ; les nouveaux modules utilisent une entité principale orientable et un stock enfant distinct.

## Travail abandonné

La première interprétation « dépôt placé de l'un des quatre côtés d'une voie » a été abandonnée sur instruction de Geoffrey. Ses essais ont été archivés hors du dépôt ; aucun de ces changements n'est actif dans le prototype. Le lot précédent reste enregistré dans le commit `f14769e`.
