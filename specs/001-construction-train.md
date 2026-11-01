# 001 — Train autonome de construction ferroviaire

**Statut** : lot 1 accepté en sandbox le 1er novembre 2026 ; poursuite du lot 2, branches et concurrence.
**Demandé par** : Geoffrey.
**Date** : 2026-10-28.
**Conception détaillée** : [LLD](../docs/LLD.md).
**Besoin original** : [passation](../passation.txt).

## Problème

Les robots de construction transportent lentement les matériaux vers de très grands chantiers ferroviaires. Le joueur souhaite confier leur construction à des trains ravitaillés, en conservant ses blueprints et la responsabilité du tracé.

## Solution

La pose réelle d’un bâtiment génère et lui rattache une unique machine de chantier complète de composition fixe locomotive — wagon central — locomotive. Elle construit les ghosts ferroviaires au contact des outils de ses deux têtes. Le wagon central porte le stock ; les locomotives orientées vers l’extérieur permettent de travailler dans les deux sens. Le train avance exclusivement sur les rails réels, se ravitaille au dépôt et traite progressivement les embranchements. Le pathfinder natif assure la navigation.

## Périmètre

Rails au sol vanilla, signaux, chain signals, arrêts, dépôt, matériaux et qualités réels, branches, plusieurs travailleurs, persistance et diagnostic. L’exclusivité par rapport aux robots est activée uniquement par les bâtiments réels et peut être désactivée ; sa mise en œuvre nécessite la qualification décrite dans le LLD.

## Hors périmètre initial

Flotte partagée entre bâtiments, assemblage manuel du train, compositions modulables et wagons supplémentaires, génération de tracé, construction à distance, bâtiments génériques, terrassement, démolition, rails surélevés et compatibilité non testée avec des rails moddés.

## Critères d’acceptation

- [ ] **AC1** Chaque rail posé correspond à un ghost existant et à un contact physique démontré de l’outil ; le train avance réellement entre deux poses.
- [ ] **AC2** Droites, diagonales et courbes vanilla au sol fonctionnent dans les orientations qualifiées.
- [ ] **AC3** Signaux, chain signals et arrêts ne sont construits que sur la voie réellement desservie ; une branche voisine n’est pas traitée par proximité.
- [ ] **AC4** Les matériaux exacts et leur qualité proviennent de l’unique wagon central ; un échec restitue le paiement intégralement.
- [ ] **AC5** Le train navigue uniquement sur des rails réels, respecte les signaux et revient au dépôt sans téléportation.
- [ ] **AC6** Un ghost isolé n’est pas affecté avant son raccordement au réseau réel accessible.
- [ ] **AC7** Le train termine une branche, se dégage complètement et traite une seconde branche atteignable.
- [ ] **AC8** La passe rails précède celle des accessoires ; une rupture de stock déclenche le ravitaillement et la reprise des rails, sans signalisation prématurée. Les accessoires sont ensuite posés au contact sur un parcours permettant la sortie.
- [ ] **AC9** Plusieurs trains ne construisent ni ne paient deux fois le même ghost.
- [ ] **AC10** Le dépôt charge un train réellement au quai selon des objectifs configurables et permet son nouveau départ.
- [ ] **AC11** Sauvegarde, rechargement, attelage, séparation et destruction ne dupliquent pas de stock et ne laissent pas de claim active orpheline.
- [ ] **AC12** La reprise de contrôle par le joueur suspend les commandes automatiques et les blocages indiquent une action utile.
- [ ] **AC13** L’option exclusive empêche les nouveaux départs des robots concernés, les robots déjà en route restant autorisés à terminer, garde de vrais ghosts et préserve les opérations natives validées ; elle n’agit que lorsqu’au moins un bâtiment réel de la même force/surface la demande, et la dernière désactivation ou disparition déclenche automatiquement la restitution ; elle n’est pas déclarée livrée avant E17.
- [ ] **AC14** Les files sont bornées par tranche, sans perte de travail ni famine ; les benchmarks du LLD produisent une comparaison au témoin.
- [ ] **AC15** Le paquet se charge réellement dans Factorio 2.1, avec GUI et prototypes vérifiés.
- [ ] **AC16** Une machine comporte exactement deux locomotives de chantier orientées vers l’extérieur et son wagon central ; les deux têtes peuvent construire, et une séparation ou un véhicule ajouté suspend l’automatisation.
- [ ] **AC17** Poser un bâtiment valide génère exactement une machine complète et son arrêt intégré ; poser deux bâtiments génère deux machines distinctes, chacune définitivement rattachée au sien.
- [ ] **AC18** Un ghost de bâtiment ou une pose échouée ne crée aucune machine et n’active pas l’exclusion ; un rechargement restaure la machine et la politique existantes sans nouvelle génération.
- [ ] **AC19** Le retrait du bâtiment retire aussi ses véhicules même éloignés ou endommagés, conserve localement leurs contenus sans perte ni duplication et ne supprime pas un occupant. Aucun second train n’est généré automatiquement.

## Phases

Le lot 1 constitue le premier point de sauvegarde du prototype jouable. Geoffrey a confirmé sur sa sandbox la construction complète des rails puis des signaux, ainsi que la reprise du chantier après déconstruction par les robots puis restauration du plan. Cette recette manuelle complète les preuves moteur ; elle ne qualifie pas à elle seule tous les critères de la cible complète. Les cases restent ouvertes lorsqu’un critère contient encore des situations non exercées.

Le lot 2 poursuit la phase « branches et concurrence » : deux machines sur un même réseau, réservation des travaux, libération après interruption et absence de double paiement. Les cendres Py restent un sujet ultérieur explicitement différé.

| Phase | Couvre | Impact sur les données | Définition de terminé |
| --- | --- | --- | --- |
| 0 — Preuves moteur | AC1, AC2, AC5, AC8, AC13, AC16 | Données temporaires d’investigation | Contact courbe qualifié, inversion réelle, réservation réversible et boucle avec rupture de stock démontrées |
| 1 — Une machine complète | AC1, AC2, AC3, AC4, AC5, AC6, AC8, AC10, AC11, AC12, AC13, AC16, AC17, AC18, AC19 | storage.ct, phases du chantier, machine et récupération | Un bâtiment, une boucle en deux passes, ravitaillement, sauvegarde et retrait sûrs |
| 2 — Branches et concurrence | AC7, AC9, AC11, AC12, AC17, AC18 | Claims, lots et générations | Deux bâtiments et deux machines indépendantes, branches et reprise sans double paiement |
| 3 — Graphismes et performances | AC14, AC15 | Files, migrations éventuelles et diagnostic | Comparaison visuelle dans le moteur et benchmarks ; concept conservé comme référence |
| 4 — Diffusion | AC15 | Aucun changement fonctionnel prévu | Paquet reproductible et documentation fidèle au jeu |

## Points ouverts

Les preuves moteur restantes sont détaillées dans les sections 6, 11, 14 et 23 du LLD. Les essais de phase 0 et le runtime du premier prototype sont présents. Le scénario intégré couvre une boucle en deux passes, le ravitaillement, le rechargement et le retrait ; les critères restent ouverts tant que toutes leurs géométries et situations ne sont pas qualifiées. Cet état ne vaut pas autorisation de publication.
