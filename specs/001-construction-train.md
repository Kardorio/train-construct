# 001 — Train autonome de construction ferroviaire

**Statut** : lot 1 accepté en sandbox ; révision machine unique et pose en mouvement acceptée par Geoffrey en sandbox le 2 novembre 2026.
**Demandé par** : Geoffrey.
**Date** : 2026-10-28.
**Conception détaillée** : [LLD](../docs/LLD.md).
**Besoin original** : [passation](../passation.txt).

## Problème

Les robots de construction transportent lentement les matériaux vers de très grands chantiers ferroviaires. Le joueur souhaite confier leur construction à des trains ravitaillés, en conservant ses blueprints et la responsabilité du tracé.

## Solution

La pose réelle d’un bâtiment génère et lui rattache une unique machine de chantier complète de composition fixe locomotive — wagon central — locomotive. Elle construit les ghosts ferroviaires au contact des outils de ses deux têtes. Le wagon central porte le stock ; les locomotives orientées vers l’extérieur permettent de travailler dans les deux sens. Le train avance exclusivement sur les rails réels, se ravitaille au dépôt et traite progressivement les embranchements. Le pathfinder natif assure la navigation.

## Périmètre

Rails au sol vanilla, signaux, chain signals, arrêts, dépôt, matériaux et qualités réels, branches, une machine par force et surface, persistance et diagnostic. L’exclusivité par rapport aux robots est activée uniquement par les bâtiments réels et peut être désactivée ; sa mise en œuvre nécessite la qualification décrite dans le LLD.

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
- [ ] **AC8** Une rupture de stock déclenche le ravitaillement et la reprise des rails. Les accessoires au contact sont posés au passage seulement si le retour au dépôt reste possible ; les autres sont différés.
- [ ] ~~**AC9** Plusieurs trains ne construisent ni ne paient deux fois le même ghost.~~ Remplacé par AC20 après la collision à quatre trains.
- [ ] **AC10** Le dépôt charge un train réellement au quai selon des objectifs configurables et permet son nouveau départ.
- [ ] **AC11** Sauvegarde, rechargement, attelage, séparation et destruction ne dupliquent pas de stock et ne laissent pas de claim active orpheline.
- [ ] **AC12** La reprise de contrôle par le joueur suspend les commandes automatiques et les blocages indiquent une action utile.
- [ ] **AC13** L’option exclusive empêche les nouveaux départs des robots concernés, les robots déjà en route restant autorisés à terminer, garde de vrais ghosts et préserve les opérations natives validées ; elle n’agit que lorsqu’au moins un bâtiment réel de la même force/surface la demande, et la dernière désactivation ou disparition déclenche automatiquement la restitution ; elle n’est pas déclarée livrée avant E17.
- [ ] **AC14** Les files sont bornées par tranche, sans perte de travail ni famine ; les benchmarks du LLD produisent une comparaison au témoin.
- [ ] **AC15** Le paquet se charge réellement dans Factorio 2.1, avec GUI et prototypes vérifiés.
- [ ] **AC16** Une machine comporte exactement deux locomotives de chantier orientées vers l’extérieur et son wagon central ; les deux têtes peuvent construire, et une séparation ou un véhicule ajouté suspend l’automatisation.
- [x] **AC17** Poser un bâtiment valide génère exactement une machine complète et son arrêt intégré ; une seconde pose dans la même force et surface est refusée et remboursée sans créer de véhicule.
- [ ] **AC18** Un ghost de bâtiment ou une pose échouée ne crée aucune machine et n’active pas l’exclusion ; un rechargement restaure la machine et la politique existantes sans nouvelle génération.
- [ ] **AC19** Le retrait du bâtiment retire aussi ses véhicules même éloignés ou endommagés, conserve localement leurs contenus sans perte ni duplication et ne supprime pas un occupant. Aucun second train n’est généré automatiquement.
- [x] **AC20** Une ancienne sauvegarde avec plusieurs dépôts sur une même force/surface suspend toutes ces machines sans suppression de stock ; le démarrage et le rappel restent bloqués jusqu’à récupération des dépôts supplémentaires. Les autres forces et surfaces sont indépendantes.
- [x] **AC21** Sur le scénario moteur de boucle, des rails et accessoires sont réellement posés pendant que le train roule. Le contact, les paiements exacts, le retour, la reprise manuelle et la sauvegarde restent vérifiés. Le temps de chantier est comparé au témoin avec arrêts.

## Révision validée le 2 novembre 2026

Geoffrey retient une seule machine par planète et force et demande une pose au ralenti sans arrêt systématique, rails et signaux au passage. La quantité de stock n'est pas augmentée pour masquer les ruptures. Le pathfinder natif continue de conduire sur les rails réels ; la destination peut être prolongée avant l'arrêt lorsque le prochain rail est effectivement au contact. La vitesse de travail est bornée pour ne pas franchir la fenêtre de contact entre deux observations. La circulation existante conserve sa signalisation native. Les accessoires dangereux pour le retour restent différés, même s'ils sont au contact.

Phase de révision — couvre AC8, AC17, AC20, AC21 ; impact : état de conflit des anciens dépôts et suivi du mouvement. Définition de terminé : tests moteur de refus/migration et boucle avec poses mobiles, rechargement réel, suite de régressions et tests graphiques réussis. Le précédent lot 2 de concurrence reste une investigation historique et ne constitue plus la cible du produit.

## Phases

Le lot 1 constitue le premier point de sauvegarde du prototype jouable. Geoffrey a confirmé sur sa sandbox la construction complète des rails puis des signaux, ainsi que la reprise du chantier après déconstruction par les robots puis restauration du plan. Cette recette manuelle complète les preuves moteur ; elle ne qualifie pas à elle seule tous les critères de la cible complète. Les cases restent ouvertes lorsqu’un critère contient encore des situations non exercées.

Le lot 2 initial étudiait la concurrence : deux machines sur un même réseau, réservation et absence de double paiement. Cette cible est abandonnée le 2 novembre après la collision à quatre trains au profit de la révision machine unique et pose en mouvement ci-dessus. Le déchargement des cendres Py, initialement différé, est traité dans la spécification 007.

Deux premiers scénarios moteur du lot 2 étudiaient deux boucles reliées au même réseau avec deux travailleurs actifs, puis le retrait d’un travailleur au moment où il avait réservé son prochain rail. Ces fixtures sont conservées comme historique et retirées de la suite courante. Elles ne qualifiaient pas le trafic dense et ne correspondent plus à la cible d’une seule machine.

| Phase | Couvre | Impact sur les données | Définition de terminé |
| --- | --- | --- | --- |
| 0 — Preuves moteur | AC1, AC2, AC5, AC8, AC13, AC16 | Données temporaires d’investigation | Contact courbe qualifié, inversion réelle, réservation réversible et boucle avec rupture de stock démontrées |
| 1 — Une machine complète | AC1, AC2, AC3, AC4, AC5, AC6, AC8, AC10, AC11, AC12, AC13, AC16, AC17, AC18, AC19 | storage.ct, phases du chantier, machine et récupération | Un bâtiment, une boucle en deux passes, ravitaillement, sauvegarde et retrait sûrs |
| 2 — Machine unique et mouvement | AC7, AC8, AC11, AC12, AC17, AC18, AC20, AC21 | Limite force/surface, conflit des anciennes flottes et suivi du mouvement | Refus du second dépôt, récupération des anciennes flottes, poses réelles en mouvement, retours et comparaison au témoin |
| 3 — Graphismes et performances | AC14, AC15 | Files, migrations éventuelles et diagnostic | Comparaison visuelle dans le moteur et benchmarks ; concept conservé comme référence |
| 4 — Diffusion | AC15 | Aucun changement fonctionnel prévu | Paquet reproductible et documentation fidèle au jeu |

## Points ouverts

Les preuves moteur restantes sont détaillées dans les sections 6, 11, 14 et 23 du LLD. Les essais de phase 0 et le runtime du premier prototype sont présents. Le scénario intégré couvre une boucle en deux passes, le ravitaillement, le rechargement et le retrait ; les critères restent ouverts tant que toutes leurs géométries et situations ne sont pas qualifiées. Cet état ne vaut pas autorisation de publication.
