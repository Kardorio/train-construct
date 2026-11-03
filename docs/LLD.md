# Construction Train — conception détaillée pour Factorio 2.1

Statut : prototype local ; cible révisée le 2 novembre 2026 vers une machine par force/surface et une pose en mouvement. La section 26 remplace les choix historiques de concurrence et de pose systématiquement à l'arrêt des sections 3 à 25.
Date : 28 octobre 2026. Auteur du besoin : Geoffrey.
Source du besoin : [passation.txt](../passation.txt).
Version examinée et exécutée : Factorio 2.1.24, build 87808, Linux.
Le dépôt Git local est initialisé sur master le 1er novembre 2026 pour enregistrer le lot 1 accepté en sandbox. La destination GitHub est Kardorio/train-construct ; aucune release n’est publiée.

## 1. Résultat et limites de la conception

La solution retenue est un train de chantier complet de composition fixe : locomotive — wagon central — locomotive, avec les locomotives orientées vers les deux extrémités. Chaque bâtiment posé génère et possède son unique train. Le convoi entier constitue une seule machine de chantier ; le wagon central transporte les matériaux et les deux têtes portent les outils de pose. Le train utilise le pathfinder et la conduite automatiques natifs, exclusivement sur les rails réellement construits. Le mod identifie un prochain ghost compatible avec une extrémité réelle, vérifie que l’outil de l’extrémité active du train est physiquement en contact avec cette extrémité, paie les matériaux, construit un seul élément, puis donne au train une nouvelle destination réelle.

Les embranchements deviennent des travaux indépendants à partir des rails réels déjà accessibles. Aucun graphe global des ghosts, planificateur de tracé ou recherche d’itinéraire à travers le futur réseau n’est nécessaire.

Depuis le 2 novembre, une force ne peut posséder qu'un dépôt sur une surface. Les trains préexistants en surnombre sont suspendus et récupérables. La destination de construction est prolongée dès le contact, sans imposer d'arrêt ; les accessoires compatibles avec les trajets de retour et de reprise sont posés au passage.

Les investigations de phase 0 ont permis de démarrer un premier prototype jouable. Les résultats ci-dessous distinguent les sondes expérimentales du runtime intégré ; la mécanique complète reste à qualifier. Trois sujets conditionnent la version distribuable :

1. le contact exact de l’outil sur toutes les géométries de rails au sol ;
2. le traitement différé des signaux susceptibles de rendre une impasse impossible à quitter ;
3. la réservation exclusive aux trains, qui n’a pas de commutateur individuel documenté pour les robots sur un ghost natif de la force du joueur.

Le prototype emploie une force technique sans robots, amie du propriétaire, pour conserver de véritables ghosts. Les essais confirment la copie native et la réservation réversible pour les robots de réseau et personnels ; l’ensemble des opérations d’édition et interactions entre mods reste à qualifier.

## 2. Invariants vérifiables

- Le mod ne dessine et ne crée jamais un tracé demandé implicitement : chaque entité construite correspond à un ghost préexistant.
- Toutes les destinations de navigation sont des rails réels ou des arrêts réels.
- Une connexion géométrique ne prouve ni une accessibilité orientée ni une possibilité de retour.
- La proximité dans une zone de recherche ne donne jamais une autorisation de construction.
- Chaque rail est posé depuis son joint d’entrée, au contact de l’outil de la tête active du train spécialisé.
- Un signal ou arrêt est posé uniquement par l’outil latéral lorsque l’un des outils du train dessert effectivement le rail associé. Un croisement géométrique ne suffit pas.
- Les objets payés proviennent de l’inventaire du wagon central de ce train, dans la qualité requise.
- Un échec de construction ne consomme rien ; un succès ne peut être payé deux fois.
- Aucune modification du terrain, démolition, téléportation, création de rail de service ou déplacement direct du train.
- Une machine de chantier contient exactement deux locomotives spécialisées encadrant son unique wagon central ; les deux extrémités sont outillées.
- Sans bâtiment réel demandant l’exclusion des robots, aucun ghost n’est réservé ; la désactivation de la dernière demande déclenche la restitution automatique.
- Un bâtiment possède une seule machine et chaque machine un seul bâtiment ; aucun partage de flotte ni génération répétée lors d’un rechargement.
- Une seule autorité du mod possède un train et une frontière à un instant donné.
- Les blocages se voient dans l’interface et cessent de consommer du temps de calcul en boucle rapide.

## 3. Analyse des API réellement disponibles

### 3.1 Références et méthode

La documentation HTML et JSON livrée avec le jeu installé a été lue dans :

- /home/vador/.steam/steam/steamapps/common/Factorio/doc-html/runtime-api.json
- /home/vador/.steam/steam/steamapps/common/Factorio/doc-html/prototype-api.json

Les deux indiquent la série 2.1 ; le JSON runtime examiné indique 2.1.24. La référence en ligne « latest » peut afficher des pages de versions légèrement différentes suivant leur cache. L’implémentation doit figer et tester une version minimale 2.1 précise avant publication, plutôt que supposer que chaque API existe dans toute la série.

Sources officielles :

- [LuaRailEnd](https://lua-api.factorio.com/latest/classes/LuaRailEnd.html)
- [RailExtensionData](https://lua-api.factorio.com/latest/concepts/RailExtensionData.html)
- [LuaTrain](https://lua-api.factorio.com/latest/classes/LuaTrain.html)
- [LuaTrainManager](https://lua-api.factorio.com/latest/classes/LuaTrainManager.html)
- [ScheduleRecord](https://lua-api.factorio.com/latest/concepts/ScheduleRecord.html)
- [LuaSchedule](https://lua-api.factorio.com/latest/classes/LuaSchedule.html)
- [LuaEntity](https://lua-api.factorio.com/latest/classes/LuaEntity.html)
- [LuaEntityPrototype](https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html)
- [LuaInventory](https://lua-api.factorio.com/latest/classes/LuaInventory.html)
- [Événements](https://lua-api.factorio.com/latest/events.html)
- [CargoWagonPrototype](https://lua-api.factorio.com/latest/prototypes/CargoWagonPrototype.html)
- [RailPlannerPrototype](https://lua-api.factorio.com/latest/prototypes/RailPlannerPrototype.html)
- [EntityPrototypeFlags](https://lua-api.factorio.com/latest/types/EntityPrototypeFlags.html)

### 3.2 Capacités confirmées

| Besoin | API | Usage et restriction |
| --- | --- | --- |
| Identifier un ghost | ghost_name, ghost_type, ghost_prototype, quality, unit_number | Ne pas utiliser ghost_unit_number comme identifiant du ghost : il désigne éventuellement l’ancienne entité détruite. |
| Lire les matériaux | ghost_prototype.items_to_place_this | Contient des alternatives de placement, pas une liste dont tous les objets seraient à payer ensemble. Chaque alternative a name et count. |
| Construire | ghost.revive{overflow=…, raise_revive=true} | Renvoie les objets déplacés, l’entité réelle et éventuellement un proxy de demandes. Ne prélève pas les matériaux dans le train. |
| Connexions réelles | rail.get_connected_rail{rail_direction=…, rail_connection_direction=…} | API pour des rails réels. La correspondance des directions de retour est fournie par le moteur. |
| Prolongement géométrique | rail.get_rail_end(direction).get_rail_extensions(planner_item) | Retourne name, position, direction et goal. Des rampes peuvent figurer parmi les résultats : filtrer le périmètre. |
| Position des signaux | LuaRailEnd.in_signal_location, out_signal_location et alternatives | Sert à associer exactement un ghost signal à un rail réel, y compris son orientation et sa couche. |
| Navigation | game.train_manager.request_train_path{…} | Appel synchrone ; borner steps_limit et la fréquence. Ce n’est pas un travail asynchrone avec événement de résultat. |
| Tester plusieurs objectifs | type="all-goals-penalties" | Fournit accessibilité, pénalités et steps_count. Ne garantit pas un trajet sans attente ni un retour futur. |
| Commande du train | LuaSchedule.add_record / set_records / go_to_station | Une destination rail peut porter rail_direction. Vérifier expérimentalement la convention d’approche ; elle ne se déduit pas du nom front/back. |
| Localiser le convoi | LuaTrain.get_rails(), front_stock, back_stock, front_end, back_end | front_stock n’est pas nécessairement la locomotive ni l’extrémité de chantier. |
| Identifier les trains | on_train_created, game.train_manager.get_train_by_id | Les identifiants changent lors d’un attelage ou d’une séparation. |
| Suivre les disparitions | script.register_on_object_destroyed, on_object_destroyed | Nettoyage idempotent ; il peut intervenir après l’invalidation effective. |
| Appartenance | LuaControl.force, accessible sur une entité | Écriture disponible, y compris sur le ghost testé ; ce n’est pas une permission de robots indépendante. |
| Détection des robots | is_registered_for_construction() | Lecture uniquement. false peut signifier qu’un robot est déjà en route ; ce n’est pas une preuve de désactivation. |

### 3.3 Résultats d’essais moteur réels

La [sonde reproductible](../tools/api_probe.py) utilise une composition fixe locomotive — wagon cargo — locomotive. Les véhicules sont encore les prototypes vanilla : elle éprouve les API et la cinématique, pas les illustrations ni les prototypes définitifs de la machine.

Deux profils indépendants symétriques ont été exécutés dans Factorio de base 2.1.24, extensions explicitement désactivées. Chaque profil est créé dans un dossier temporaire, sauvegardé puis exécuté pendant 3 601 ticks. Le premier construit vers le sud, le second vers le nord.

Observations et assertions :

- trois véhicules appartiennent au même train, avec une locomotive orientée vers chaque extrémité ;
- le pilote automatique natif amène la locomotive de tête vers une destination de type rail réel et s’y arrête ;
- les positions demandées sont ajustées à la grille ferroviaire : utiliser les positions réellement retournées ;
- dix prolongements droits sont créés successivement depuis de vrais ghosts dans chacun des deux profils ;
- avant chaque pose, le point d’outil proposé à quatre cases du centre de la locomotive de tête coïncide exactement avec le joint du rail réel ;
- la locomotive avance réellement de deux cases entre les poses successives sur ces voies droites ;
- dans le profil sud, le premier contact est au joint (1, 62), depuis une tête au centre (1, 58) ; dans le profil nord, il est au joint (1, -60), depuis une tête au centre (1, -56) ;
- les matériaux sont prélevés exclusivement dans le wagon central : chaque profil passe de 100 à 90 objets rail pour dix poses ;
- get_rail_extensions fournit les prolongements canoniques depuis un rail réel ;
- get_connected_rails sur un ghost de signal échoue avec « Entity is not rail-signal. » ;
- get_rail_end sur un ghost de rail échoue avec « Entity is not rail. » ;
- changer la force d’un ghost de signal conserve son type et ses tags dans l’essai élémentaire ;
- un roboport alimenté et approvisionné construit le ghost témoin de sa force, tandis que le ghost transféré dans une force technique reste intact après 3 600 ticks.

Un outil calculé n’est pas encore une pièce physique finalisée : sa position doit être traduite dans le prototype graphique et éprouvée sur les autres géométries. Les propriétés front_end et back_end du train ne constituent pas seules une preuve de contact avec le joint visé ; vérifier le repère de l’outil réel.

Reproduction : `python3 tools/api_probe.py`, avec FACTORIO_BIN facultatif. Le programme conserve le [journal de résultats](api-probe-results.txt) et supprime les profils temporaires. Il ne touche ni aux mods actifs ni aux sauvegardes du joueur.

Ces scénarios valident la progression droite dans deux orientations opposées et le prélèvement central. Ils ne démontrent pas encore une inversion de mission sur le même train, les courbes, les manœuvres d’aiguillage, la pose des signaux en circulation, l’expérience blueprint entre forces, les prochains départs des robots personnels, ni les performances d’une megabase.

### 3.4 Ce qu’il ne faut pas supposer

Il n’existe pas, dans le JSON runtime examiné, de setter individuel documenté du type ghost.allow_construction_robots ou unregister_for_construction. Les flags not-deconstructable et not-repairable ne désactivent pas la construction d’un ghost.

Les méthodes ferroviaires refusées par les ghosts ne seront pas utilisées sous prétexte que la description générale de LuaEntity indique que beaucoup de méthodes fonctionnent sur les ghosts.

Une intersection de bounding boxes de rails courbes n’est pas une connexion ferroviaire. Une destination atteinte n’est pas un contact physique. Une requête de chemin réussie n’est pas une réservation de circulation.

### 3.5 Essais complémentaires du 30 octobre 2026

Commande : `python3 tools/rail_geometry_probe.py`. [Scénario Lua](../tools/probes/rail_geometry.lua), [pilote Python](../tools/rail_geometry_probe.py) et [journal complet](rail-geometry-results.txt).

Huit scénarios ont été exécutés dans des profils isolés : quatre orientations cardinales, courbe gauche et courbe droite pour chacune. Les trajets couvrent straight-rail, half-diagonal-rail, curved-rail-a et curved-rail-b. Dans chaque cas, la conduite native parcourt l’extension, ramène le même train en marche arrière, puis cinq rails droits sont construits depuis l’autre locomotive devenue tête.

Chaque scénario réanime 27 rails, prélève exactement 39 objets rail dans le wagon central et retrouve les 461 objets restants sur 500. L’identité du train est contrôlée pendant l’inversion ; les trois véhicules restent liés.

Limite importante : la partie courbe est une sonde de navigation et de mesure. Elle relève le contact puis réanime le ghost même si le point rigide échoue ; ce comportement d’investigation ne doit jamais être repris dans le mod final. Sept mesures par scénario dépassent la tolérance du point rigide, avec un écart maximal de 0,4881 case. Les cinq poses après inversion vérifient effectivement le contact droit de l’autre tête.

Conclusion : navigation courbe/semi-diagonale et inversion démontrées sur ces tracés ; contact frontal rigide insuffisant. Le nez doit comporter un mécanisme articulé avec une enveloppe physique et un contact final exact à qualifier. Aucun élargissement arbitraire d’un rayon de construction n’est validé par ces résultats.

### 3.6 Contact articulé et cycle de vie — essais du 30 octobre 2026

#### Contact borné avant chaque pose

Commande : `python3 tools/rail_contact_probe.py`. [Scénario Lua](../tools/probes/rail_contact.lua), [pilote](../tools/rail_contact_probe.py) et [journal](rail-contact-results.txt).

La nouvelle sonde reprend les huit orientations/sens de virage, mais impose un contact réussi AVANT tout paiement ou revival. Après retour du même train, l’autre tête construit également un second tracé courbe et semi-diagonal ; elle ne se limite plus aux cinq rails droits de la première sonde.

Modèle physique candidat : pivot à trois cases devant le centre de la locomotive, bras court de longueur comprise entre 0,8 et 1,2 case, articulation de ±30°. Sa pointe reconstruite dans le monde doit coïncider avec le joint canonique à moins de 1/256 de case. Le ghost doit en outre correspondre exactement à un prolongement natif de ce joint. Deux contre-exemples par pose vérifient qu’une cible trois cases plus loin ou trois cases sur le côté est refusée.

Résultats : huit scénarios réussis, 44 poses et 44 contacts contrôlés par scénario, soit 352 poses au total. Chaque wagon central passe de 500 à 432 objets rail, avec 68 objets consommés exactement. Les quatre types de rails au sol sont exercés. Le débattement maximal observé est de 27,4421° et la longueur du bras varie de 1 à 1,04824 case.

Ces résultats valident ce modèle géométrique sur les tracés testés. Il reste à le matérialiser dans le prototype visuel et les animations, puis à qualifier aiguillages, croisements, obstacles, rails moddés éventuels et autres contre-exemples. La sonde n’est pas le mod final et ne démontre pas toute sa gestion de chantier.

#### Réservation réversible et récupération locale

Commande : `python3 tools/lifecycle_probe.py`. [Scénario Lua](../tools/probes/lifecycle.lua), [pilote](../tools/lifecycle_probe.py) et [journal](lifecycle-results.txt).

Dans un profil isolé avec roboport, robots et matériaux :

- sans demande, le ghost témoin est construit ;
- avec une demande, le vrai ghost transféré dans la force technique reste intact ;
- deux demandes puis désactivation de la première : la seconde maintient la réservation ;
- suppression de la dernière demande active : le ghost est rendu à la force du joueur et les robots le construisent ;
- un bâtiment désactivé, puis l’absence de tout bâtiment, ne bloque pas les ghosts témoins suivants.

Les bâtiments sont ici représentés par des coffres vanilla et un petit registre de demandes propre au scénario. Cela démontre la réversibilité moteur et le comportement des robots de réseau, pas les événements, GUI et génération de machine du futur bâtiment. Les prochains départs de robots personnels et l’édition native des ghosts entre forces restent à qualifier.

La même sonde crée un train de trois véhicules, dépose ses piles réelles localement puis retire ses véhicules. Comptage au sol après retrait : 100 rails, 23 signaux, 17 chain signals et 100 charbons, sans perte ni objet supplémentaire. Ce test couvre des piles normales sur terrain disponible, sans occupant ; il ne qualifie pas encore les cas d’inventaire spécial, d’occupant, de zone saturée, de carburant en cours de combustion ou de reprise après interruption du démontage.

La boucle complète a depuis été éprouvée dans huit profils ; les résultats et les limites sont détaillés dans la section 3.7.

### 3.7 Boucle avec ravitaillement et signalisation — essais du 30 octobre 2026

Commande : `python3 tools/rail_loop_probe.py`. [Scénario Lua](../tools/probes/rail_loop.lua), [pilote](../tools/rail_loop_probe.py) et [journal](rail-loop-results.txt).

Huit profils isolés couvrent quatre orientations et deux sens de boucle. Dans chacun :

1. la machine commence avec seulement sept objets rail dans le wagon central ;
2. elle construit au contact, s’arrête faute de matériaux et conserve les deux accessoires en ghosts ;
3. le même train revient réellement au point de ravitaillement, où un coffre fournit 200 objets rail ; la position du wagon et l’arrêt du train sont contrôlés ;
4. elle reprend à la frontière abandonnée et ferme la boucle sur le réseau réel ; les connexions sont vérifiées avec le moteur ;
5. après 52 poses de rails, sans aucun signal construit prématurément, elle engage la seconde passe ;
6. elle pose un signal et un chain signal au contact de l’outil latéral candidat ; le signal réel doit confirmer son rattachement au rail attendu ;
7. après chaque accessoire, le pathfinder natif confirme encore un trajet de sortie ;
8. le train revient réellement au point de ravitaillement, avec ses trois véhicules et le même identifiant.

Chaque scénario consomme exactement 84 objets rail, un signal et un chain signal. La somme des stocks du wagon et du coffre est conservée après paiement. Au total, les huit profils couvrent 416 poses de rails, huit ravitaillements et seize accessoires.

La sonde n’est pas l’automate final : son trajet est une fixture connue et le ravitaillement est représenté par un coffre vanilla. Les signaux testés sont situés sur des portions droites, dans une orientation compatible avec le retour. Le modèle latéral candidat est borné à la longueur de la locomotive, entre -4 et +4 cases longitudinales et jusqu’à 3 cases latérales ; les coordonnées mesurées et les ancrages réels sont consignés. Cela ne qualifie pas les signaux sur toutes les courbes, les gares, tous les plans de sens uniques ou une flotte de production concurrente.

Conclusion : les deux passes résolvent bien le scénario de rupture de stock testé. La vérification d’une sortie réelle pendant la seconde passe reste obligatoire ; la fermeture d’une boucle ne rend pas toutes les orientations de signaux automatiquement praticables.

### 3.8 Copie native des ghosts réservés — limite découverte et correction candidate

Commande : `python3 tools/ghost_editing_probe.py`. [Scénario](../tools/probes/ghost_editing.lua), [pilote](../tools/ghost_editing_probe.py) et [journal](ghost-editing-results.txt).

La création native d’un blueprint avec la force du joueur inclut le ghost témoin mais omet le ghost transféré dans une force technique non amie : un élément copié avant réservation, zéro pendant. La restitution de la force propriétaire le rend à nouveau copiable.

Une amitié mutuelle entre la force du joueur et sa force technique permet de recopier ce ghost sans le restituer. Cette relation est limitée à la force technique propre à ce propriétaire ; elle ne rend pas amies les forces de joueurs distincts.

La vérification complémentaire `CT_FRIENDLY=1 python3 tools/lifecycle_probe.py` ([journal](lifecycle-friendly-results.txt)) confirme que, dans le scénario de robots de réseau, cette amitié ne déclenche pas la construction du ghost réservé. La dernière désactivation le restitue et les robots le construisent normalement ; les contrôles de demandes multiples et de récupération locale passent également.

La force technique non amie est donc rejetée pour l’implémentation prévue. La variante amie est une piste éprouvée pour la copie native et les robots de réseau, pas une preuve de toute l’édition en jeu. Les robots personnels, le minage/annulation par l’interface, l’upgrade, le couper-coller, les fils et les fusions de forces restent à qualifier.

## 4. Expérience joueur et périmètre initial

1. Rechercher la technologie de chantier ferroviaire.
2. Poser le bâtiment de chantier à côté d’une voie de service droite préparée et raccordée par le joueur.
3. La pose valide du bâtiment génère automatiquement sa machine complète locomotive — wagon central — locomotive et son arrêt de service intégré.
4. Alimenter le bâtiment par bras ou manuellement, puis définir les objectifs de chargement de son train.
5. Le réglage « Réserver l’infrastructure ferroviaire aux trains », activé par défaut à la pose réelle du bâtiment, peut être désactivé dans sa fenêtre.
6. Poser les blueprints ferroviaires habituels ; le train rejoint les frontières accessibles, construit au contact et revient à son propre bâtiment.
7. Pour disposer de deux trains, poser deux bâtiments. Le joueur prépare leurs raccordements et leur acheminement sur le réseau réel.
8. L’interface indique les chantiers isolés, les blocages et la progression d’activation ou de désactivation de la réservation.

La relation est stricte : un bâtiment possède un emplacement de machine et génère un seul train. Pas d’assemblage manuel des trois véhicules, pas d’inscription d’un train extérieur, pas de flotte partagée ou de réaffectation automatique entre bâtiments.

Périmètre de la première version fonctionnelle : straight-rail, half-diagonal-rail, curved-rail-a, curved-rail-b, rail-signal, rail-chain-signal et train-stop vanilla. Les identifiants doivent être revérifiés dans les prototypes chargés. Pas de legacy rail, de rampe, de rail surélevé ou de support en première version. Un accessoire associé à une voie surélevée est également exclu.

Les packs et véhicules moddés ne sont pas annoncés compatibles avant un essai dédié. Les adaptateurs de recettes et de technologies s’inspireront des packs réellement installés, comme dans les autres mods.

## 5. Entités, prototypes, recettes et technologie

### 5.1 Machine de chantier complète : locomotive — wagon — locomotive

La composition choisie par Geoffrey est fixe :

    [← locomotive de chantier A] — [wagon central de matériaux] — [locomotive de chantier B →]

Il s’agit d’un seul engin de chantier à deux cabines. L’extrémité qui mène change selon le sens de déplacement ; les deux têtes savent construire. Le wagon central ne donne pas une capacité de construction autonome à un train ordinaire.

Factorio représente techniquement l’engin par trois entités de matériel roulant natives, reliées dans un même LuaTrain. Ce choix respecte la physique des rails, des courbes et des attelages ; une locomotive unique portant un très long sprite ne représenterait pas correctement les articulations. Le mod enregistre cependant une seule machine, avec un seul état, une seule affectation, un seul dépôt et un seul profil de stock.

Prototypes :

- ct-construction-locomotive, type locomotive, utilisé aux deux extrémités et orienté vers l’extérieur ; chaque tête porte l’outil frontal et les outils latéraux ;
- ct-construction-wagon, type cargo-wagon, exclusivement au centre ; inventaire proposé de 100 emplacements, filtres et barre natifs, qualité sans gain de portée ;
- pas d’ajout de wagons pour augmenter la capacité et pas de composition alternative.

La pose valide du bâtiment génère automatiquement les trois véhicules spécialisés, leurs attelages et leur liaison définitive à ce bâtiment. Le joueur n’assemble pas le train. Un bâtiment possède une seule machine ; obtenir deux machines exige deux bâtiments.

Les possibilités techniques natives d’attelage et de séparation restent présentes. Toute séparation, orientation incorrecte, destruction ou ajout d’un véhicule suspend la machine ; le mod ne détruit ni ne réarrange automatiquement les éléments. La remise en service exige que la composition fixe soit à nouveau complète.

Visuellement, les trois parties partagent une même identité industrielle et doivent être perçues comme une seule machine. Aucun roboport, robot invisible ou rayon de couverture. Les outils de chaque tête sont visibles et possèdent des surfaces de contact explicites. Les matériaux sont convoyés à l’intérieur de cette machine depuis le wagon central : leur transfert interne ne constitue pas une construction à distance.

### 5.2 Bâtiment de chantier et génération de son train

Entité principale proposée : ct-construction-depot, type container, stock de 100 emplacements avec filtres et barre. Le bâtiment matérialise le dépôt de sa machine et ses équipements fixes de chargement. L’empreinte visuelle est à dimensionner autour de la voie de service et des trois véhicules ; une petite caisse isolée de 4×4 ne représente plus à elle seule ce bâtiment.

Le joueur prépare une voie droite au sol, assez longue pour la machine et raccordée à son réseau. La prévisualisation du bâtiment montre l’ancrage, le côté de service, les positions des trois véhicules et la longueur nécessaire. Le bâtiment ne génère aucun tracé ferroviaire, même pour son quai. L’arrêt ct-depot-stop est un composant technique du bâtiment, créé automatiquement à l’emplacement validé ; aucun arrêt séparé à fabriquer ou associer dans la GUI.

Une pose réelle valide — par joueur, robot ou revival — déclenche une seule transaction :

1. revalider les rails réels, l’emprise libre, les orientations, la même force/surface et l’absence d’un train occupant le quai ;
2. créer un identifiant durable de bâtiment et un jeton de génération ;
3. créer l’arrêt de service et les trois véhicules spécialisés aux positions canoniques ;
4. vérifier qu’ils forment exactement le même train, avec une traction dans chaque sens ;
5. enregistrer la relation bâtiment ↔ machine, le stock central et le planning privé ;
6. seulement après succès complet, rendre le bâtiment opérationnel et comptabiliser sa demande éventuelle d’exclusion des robots.

Une prévisualisation ou un ghost de bâtiment ne génère aucun train et ne change pas le comportement des robots. Une pose impossible est refusée avec explication et restitution exacte de l’objet bâtiment ; les composants partiellement créés sont annulés sans laisser de train, gare ou jeton actif. Le traitement de la restitution diffère selon l’origine joueur/robot/script et fait l’objet de scénarios moteur. Ne jamais consommer un second bâtiment lors d’un événement de création doublonné.

Le jeton et les identifiants des trois composants rendent la création idempotente : sauvegarde/rechargement, réindexation et événements script ne génèrent pas une nouvelle machine pour un bâtiment qui a déjà la sienne. Deux bâtiments ne peuvent ni partager la même machine ni exploiter des emprises de quai qui se chevauchent.

Le train transporte les matériaux de chantier et reste la propriété de ce bâtiment durant ses missions. Les transferts se font seulement lorsque sa machine complète est réellement arrêtée à son propre quai. La longueur utile est déduite de la composition fixe. Aucune alimentation ni construction à distance.

#### Retrait, destruction et remplacement

Le retrait doit rester possible même si le train est loin, coincé ou endommagé. Il ne dépend plus obligatoirement de son retour au quai. Le rappel reste disponible pour un retrait confortable, mais n’est pas une condition permettant de bloquer définitivement le bâtiment.

La récupération explicite du bâtiment arrête la mission et retire également ses trois véhicules, à leurs positions réelles :

1. annuler les nouvelles affectations et les claims puis immobiliser la machine liée ;
2. vérifier l’absence de joueur à bord avant toute suppression ; ne pas supprimer une entité occupée ;
3. mettre en sécurité les piles réelles du wagon central et les carburants/résidus des deux locomotives ;
4. déposer ces objets au sol près de chaque véhicule sur sa surface, sans transporter le fret jusqu’au bâtiment ou au joueur ;
5. vérifier les quantités et conserver tout dépôt impossible dans une récupération persistante visible, sans supprimer ni dupliquer les piles ;
6. retirer les seuls véhicules de cette machine et son arrêt intégré, puis finaliser la récupération du bâtiment ;
7. retirer sa demande d’exclusion des robots et restituer les ghosts si c’était la dernière demande.

Le bâtiment récupéré représente l’ensemble déjà payé ; ne pas produire en plus des objets locomotives/wagon indépendants. Un jeton de démontage rend l’opération idempotente, y compris si un événement intervient entre deux véhicules ou après rechargement. Cette suppression à distance ne construit ni ne téléporte rien : elle laisse les matériaux à l’endroit où se trouvait le train.

En cas de destruction forcée du bâtiment, aucun objet bâtiment n’est remboursé. Les composants survivants sont arrêtés et traités par la même procédure de conservation locale des contenus, sans création de matériel neuf. Un occupant impose une récupération différée explicite plutôt que sa disparition silencieuse.

Une machine détruite ou scindée passe en état MACHINE_DAMAGED ; aucune disparition de référence ne déclenche un second train automatique. La récupération du bâtiment traite les composants survivants et reste possible. Une fonction de réparation/remplacement éventuelle nécessite une action explicite et un coût sans duplication ; son équilibrage ne bloque pas l’existence d’une procédure sûre de retrait.

### 5.3 Valeurs de départ proposées

| Prototype | Recette de départ | Déblocage |
| --- | --- | --- |
| Bâtiment complet avec sa machine | 2 locomotive, 1 cargo-wagon, 4 steel-chest, 40 steel-plate, 40 iron-gear-wheel, 30 electronic-circuit | Technologie ct-railway-construction |

Les deux locomotives spécialisées, le wagon central et l’arrêt intégré sont des prototypes internes, sans recettes de fabrication ni items de pose indépendants destinés au joueur. Le coût de la recette du bâtiment inclut sa machine : la génération à la pose ne crée pas de matériel gratuit renouvelable.

Technologie : prérequis railway et automated-rail-transport, 150 unités de 30 secondes avec automation-science-pack et logistic-science-pack. Ces dosages sont des propositions d’équilibrage réversibles, à valider dans les prototypes réellement disponibles. Les packs de conversion ne reçoivent aucune référence à un item supposé exister. Pas de science logistique robotique requise par principe.

Items, recettes et technologie ont des identifiants préfixés ct-. L’archive utilisera info.json, data.lua, prototypes/, control.lua, scripts/, graphics/, locale/fr/, locale/en/, changelog.txt et build.sh, comme les projets voisins. La création des illustrations viendra après validation du fonctionnement mécanique.

## 6. Contact physique : contrat précis

### 6.1 Pourquoi une distance au train ne convient pas

Le rayon d’une recherche locale sert uniquement à limiter les candidats. Ni le rayon de recherche, ni la présence du wagon central dans un convoi quelconque, ni son arrêt sur un rail voisin ne sont des autorisations.

Le résultat moteur de la section 3 montre un écart entre caisse, extrémité logique du train et joint réel. Il faut donc une géométrie d’outil propre au prototype. Un seuil « à moins de dix cases du train » serait contraire au besoin.

### 6.2 Géométrie de l’outil

Les deux locomotives spécialisées et le wagon central déclarent dans scripts/contact.lua les outils de la machine complète :

- le repère local de l’outil frontal au nez extérieur de chaque locomotive ;
- une petite surface de contact de cet outil ;
- les surfaces de contact des outils latéraux des deux têtes et, si nécessaire, du module central ;
- l’extrémité du véhicule qui porte l’outil.

Chaque point est transformé dans le monde depuis la position et l’orientation réelles du véhicule qui porte cet outil, puis rattaché au même travailleur logique représentant les trois véhicules. La tolérance numérique est distincte des dimensions physiques : au plus 1/256 de case pour comparer des coordonnées canoniques après validation.

Le point rigide à quatre cases du centre est insuffisant en courbe. Le modèle candidat éprouvé sur les huit tracés du 30 octobre utilise un pivot à trois cases devant le centre, un bras de 0,8 à 1,2 case et une articulation de ±30°. Sa pointe doit toucher exactement le joint canonique, et le ghost doit être un prolongement natif de celui-ci. Les dimensions et animations du prototype devront matérialiser ce mécanisme. Cette enveloppe mécanique ne donne aucun droit de construire un ghost voisin ou éloigné, même situé à une distance comparable.

Pour un rail, le joint d’entrée canonique doit appartenir à cette surface, correspondre à la couche desservie et se trouver du côté extérieur de la locomotive de tête active. Le ghost doit être un prolongement exact de ce joint.

Pour un accessoire, le rail de rattachement doit être un rail réellement desservi par l’outil considéré de cette machine, et le pied de l’accessoire doit être atteint par son outil latéral. Les grandes courbes et diagonales demandent des essais réels ; si la géométrie n’est pas qualifiée, arrêt avec diagnostic plutôt qu’élargissement silencieux du contact.

### 6.3 Progression

Le train reçoit une destination rail réelle en conduite native. À l’arrivée :

1. vérifier vitesse nulle et stabilité de la position sur deux vérifications ;
2. identifier les trois composants de la machine et la locomotive extérieure qui porte l’outil actif, sans supposer que front_stock correspond au sens de chantier ;
3. identifier le joint réel ciblé et vérifier son contact ;
4. construire au plus un prolongement rail ;
5. ajouter une destination sur le rail devenu réel, avec la bonne orientation d’approche ;
6. attendre que le train ait réellement avancé avant d’autoriser le prolongement suivant.

On ne pose pas une rafale de rails sous prétexte qu’ils sont tous connectés au premier. Après chaque pose, la position réelle de la tête active doit progresser. Sans mouvement possible, le train est bloqué ; aucune téléportation ni écriture forcée de LuaTrain.speed ne compense le problème.

La première version accepte une progression pas à pas, avec un coût de repath par rail. L’optimisation ultérieure peut laisser le train rouler lentement seulement si le contact et la circulation restent prouvés. Un meilleur débit ne justifie jamais une pose anticipée hors contact.

## 7. Modèle de données et persistance

Toutes les données durables sont sous storage.ct, avec schema_version. Les modules sont des tables de fonctions Lua, sans hiérarchie de classes ni services génériques.

| Collection | Clé | Champs principaux |
| --- | --- | --- |
| depots | unit_number du container | entity, stop, surface, owner_force, enabled, worker_id, generation_token, machine_status, exclude_bots, stock_targets, quai, configuration_revision |
| workers | unit_number du wagon central | locomotive_a, wagon_central, locomotive_b, active_end, train_id courant, depot_id, state, task_id, pending_accessories, route_revision, blocked_reason |
| ghosts | unit_number du ghost | entity, owner_force, surface, chunk_key, canonical_key, kind, state, reserved_mode |
| frontiers | clé stable du rail réel + extrémité + ghost | anchor, rail_direction, candidate_ghost_id, layer, owner, generation, retry_at |
| claims | frontier_id | worker_id, generation, last_progress_tick, phase |
| dirty_chunks | surface + force propriétaire | file et ensemble de déduplication |
| world_revision | surface + force propriétaire | compteur d’invalidation des caches de trajet |
| object_registrations | registration_number | type d’objet et clé de la collection |
| bot_policies | force propriétaire + surface | active_depot_ids, desired_enabled, phase, generation, scan_cursor, release_cursor |
| reserved_ghosts | ghost_id | force propriétaire d’origine, force technique, métadonnées strictement nécessaires |
| recovery | transaction_id | inventaire de secours et remboursement exceptionnel restant |

Une référence LuaEntity peut être enregistrée dans storage, mais toujours relue avec valid. Les structures LuaRailEnd sont reconstruites depuis un rail réel et une direction ; pas de dépendance à leur conservation entre sauvegardes.

canonical_key contient surface, force propriétaire, nom, position quantifiée, direction et couche lorsque disponible. Ne pas arrondir les rails à des cases entières. Les signaux opposés, rails superposés et qualités différentes ne doivent pas entrer en collision dans les index.

Éviter de recopier tous les réglages d’un ghost : l’entité native en est la source d’autorité. Les tags ct sont seulement des informations de mod et ne doivent pas écraser les tags d’un autre mod.

on_init initialise puis programme une découverte progressive. on_configuration_changed migre les structures et invalide les caches. on_load ne lit pas game, ne reconstruit pas le monde et ne modifie pas storage ; il rattache seulement les références Lua locales et les gestionnaires conditionnels nécessaires.

## 8. Index des ghosts et frontières

### 8.1 Découverte

Les événements de création enregistrent les ghosts ferroviaires admissibles et salissent leur chunk ainsi que les voisins nécessaires à leur géométrie. L’enregistrement est idempotent.

Lors de l’ajout du mod à une sauvegarde existante, parcourir progressivement les chunks déjà générés avec un curseur ; ne jamais générer de nouveaux chunks pour rechercher des travaux. Le traitement est budgété et peut être suspendu puis repris après sauvegarde.

Les mods qui créent ou détruisent silencieusement des entités ne garantissent pas les événements. Prévoir une réconciliation lente des chunks connus et un bouton « Réindexer les chantiers », sans scan global à chaque tick.

### 8.2 Construire les frontières

Pour chaque ghost rail d’un chunk sale :

1. rechercher localement les rails réels candidats ; la zone couvre les géométries au sol acceptées, pas une portée de construction ;
2. pour chaque extrémité de ces rails, interroger get_rail_extensions sur les rail-planners autorisés ;
3. comparer exactement nom, position et direction au ghost ; filtrer la couche et le périmètre ;
4. créer une frontière par correspondance ;
5. laisser les ghosts sans correspondance dans l’index isolé, sans tentative de dispatch.

Un rail réel avec une continuation réelle peut encore avoir un prolongement latéral ghost : ne pas limiter les frontières aux seuls culs-de-sac.

Les planificateurs sont découverts via leurs prototypes rail-planner et leur liste rails, avec un cache par combinaison. La première version ne qualifie que le planificateur vanilla ; les autres sont visibles comme incompatibles tant qu’un adaptateur n’a pas été validé.

### 8.3 Définition d’un chantier

L’unité de réservation est une frontière orientée, pas un blueprint entier. Un chantier affiché est une session de travail issue d’une frontière, avec sa progression et ses embranchements encore disponibles.

Cela évite d’imposer une composante connexe globale des ghosts. L’interface n’annonce pas « 12 000 rails dans ce chantier » sans les avoir comptés ; elle affiche des quantités indexées et un périmètre explicite, ou seulement la progression réalisée.

L’accessibilité appartient au couple train-frontière : une frontière peut être accessible à un train et interdite à un autre par son sens d’approche, son emplacement, ses locomotives ou les signaux.

## 9. Dispatch, navigation et réservation

### 9.1 Affectation

Toutes les 60 ticks, un ordonnanceur équitable traite quelques travailleurs prêts, en rotation.

- Choisir au plus 16 frontières candidates par travailleur.
- Donner la priorité aux reprises suspendues puis à l’ancienneté ; utiliser la distance géométrique comme présélection seulement.
- Interroger request_train_path avec les rails réels comme objectifs et return_path=false.
- Pour le trajet d’approche final, contraindre les départs et objectifs de sorte qu’une des deux têtes équipées atteigne la frontière dans le sens attendu. Les deux extrémités sont capables de construire ; mémoriser celle qui dessert cette mission et vérifier son contact.
- Vérifier séparément une possibilité de retour vers le quai depuis une position d’arrivée cohérente ; inclure les deux sens et la signalisation.
- Faire la réservation atomique dans le gestionnaire Lua après revalidation du ghost et de sa génération.
- Installer le planning privé du train et engager le trajet.

Un résultat négatif sous steps_limit ne doit pas être présenté comme une impossibilité démontrée. Distinguer « non trouvé dans le budget », « indisponible temporairement » et « géométriquement isolé » ; réessayer lentement avec un budget plus élevé plafonné ou une action utilisateur.

Le pathfinder traite la circulation ; claims ne remplace pas les réservations natives de blocs. Aucun train ne contourne un signal rouge par conduite manuelle.

### 9.2 Réservations

Une claim lie une frontière, sa génération et un travailleur. Deux claims sur deux prolongements d’un même joint forment un groupe d’exclusion afin que deux trains ne se présentent pas face au même outil.

Le train en approche conserve la claim même s’il attend un signal. Un délai ne suffit pas à réaffecter sa frontière : il faut d’abord annuler sa mission, vérifier qu’il s’est arrêté ou écarté, puis libérer. Après séparation ou destruction du train, toutes les claims concernées sont invalidées.

Une frontière réapparue au même emplacement après suppression est une nouvelle génération. Un ancien travailleur n’a pas le droit de la construire avec un jeton périmé.

### 9.3 Planning du train

La machine est générée et liée à son bâtiment lors de la pose valide. Son planning privé ne possède ni groupe partagé ni interruption de production héritée. Aucun train extérieur n’est inscrit et aucun transfert automatique vers un autre bâtiment n’est proposé.

Le mod possède alors son planning dédié. Les étapes rails doivent rester présentes pendant l’attente de chantier : ne pas supposer qu’un enregistrement temporaire supprimé par le moteur est un état durable. Utiliser les primitives LuaSchedule validées dans le scénario moteur ; les étapes privées sur rail peuvent être non temporaires puis supprimées explicitement.

Un arrêt « atteint » se reconnaît par l’objectif attendu, la vitesse et le contact réel ; pas par un numéro brut d’état natif.

Une modification de planning par le joueur, une prise de contrôle ou un passage manuel demandé par le joueur suspend la mission et cesse les écritures automatiques. Les événements produits par le mod sont distingués par une garde de mutation synchrone et une révision du planning.

## 10. Boucle de construction et paiement

### 10.1 Matériaux

Pour les matériaux de construction, ne lire et écrire que defines.inventory.cargo_wagon du wagon central identifié dans la composition fixe. Ne pas prélever le carburant, les munitions, les équipements ou le contenu du dépôt à distance.

Clé d’inventaire : item_name + séparateur + quality_name, comme dans Train Foundry. Une qualité supérieure ne remplace pas implicitement celle du ghost. Les alternatives items_to_place_this sont parcourues dans un ordre stable ; sélectionner une alternative disponible en totalité, pas une fraction de chaque alternative. Le count donné par le prototype reste l’autorité, notamment pour les courbes.

### 10.2 Transaction synchrone

Pseudo-code conceptuel ; il décrit le contrat, pas une API revive avec consommation implicite :

    revalider(worker, claim, ghost, contact, force, couche)
    cost = choisir_alternative_de_placement(ghost)
    receipt = retirer_exactement_du_wagon_central(cost, qualité)
    si prélèvement incomplet : rembourser(receipt), quitter

    marquer_transaction_en_cours()
    objets_déplacés, réelle, proxy = ghost.revive{
      overflow = inventaire_temporaire_de_récupération,
      raise_revive = true
    }

    si pas de réelle valide :
      rembourser(receipt)
      restaurer_la_réservation_du_ghost_si_nécessaire()
      classer_le_blocage()
    sinon :
      enregistrer_le_paiement_une_seule_fois()
      intégrer_le_rail_ou_accessoire()
      distribuer_les_objets_déplacés_sans_les_compter_deux_fois()
      invalider_les_caches_locaux()

Les événements script_raised_revive sont synchrones et peuvent appeler d’autres mods. Ne garder aucune hypothèse de validité après cet appel. Une garde empêche que notre propre événement déclenche une deuxième construction. La facture contient les slots, qualités et quantités réellement retirés.

Le traitement des objets déplacés doit être validé : inventaire overflow et premier retour de revive ne doivent pas être additionnés aveuglément. Si les inventaires de départ ont disparu pendant un événement externe, conserver le remboursement dans un inventaire de récupération persistant et visible ; ne rien supprimer ni créditer gratuitement. Un remboursement normal revient aux slots d’origine du wagon central ; si celui-ci a disparu, utiliser la récupération persistante. Le surplus exceptionnel est déposé au sol si une position existe, ou reste dans la récupération consultable.

Un proxy de demandes n’autorise pas la construction de machines ou le remplissage de modules. Les accessoires ferroviaires vanilla n’en ont normalement pas besoin ; une demande exotique reste un diagnostic de compatibilité.

### 10.3 Après une pose

Rechercher les extrémités du nouveau rail réel et leurs prolongements. Mettre à jour seulement le voisinage. Les ghosts voisins construits par les robots entre deux étapes sont intégrés comme rails réels s’ils correspondent ; ils ne sont ni repayés ni détruits.

Avant d’autoriser le rail suivant : exiger un déplacement mesurable de la tête active et un nouveau contact, même si le prochain ghost est déjà dans la zone de recherche.

## 11. Signaux, chain signals et arrêts

### 11.1 Association exacte

Signaux : pour les rails effectivement desservis par un outil de la machine, énumérer les positions in/out de leurs LuaRailEnd et les alternatives. Comparer position, direction et couche au ghost. En présence de plusieurs associations possibles à un croisement, conserver toutes les preuves et refuser une association ambiguë tant qu’un test moteur ne tranche pas.

Ne jamais appeler get_connected_rails sur le ghost. Après revival, appeler get_connected_rails sur le vrai signal pour vérifier l’association dans les tests et détecter un adaptateur incompatible.

Arrêts : il n’existe pas de position d’arrêt sur LuaRailEnd équivalente aux positions de signaux dans l’API examinée. Prévoir un adaptateur de géométrie vanilla explicitement testé pour les orientations et types de rails supportant réellement les arrêts. Ce module décrit des offsets issus de placements réels validés dans le moteur, et non des offsets inventés ou un test de rayon. Après revival, connected_rail du vrai train-stop doit confirmer l’ancrage attendu.

Si le rattachement d’un ghost d’arrêt ne peut pas être prouvé avant la pose, il reste ghost. Le test moteur de l’adaptateur est un préalable à l’acceptation de cette fonctionnalité.

### 11.2 Construction en deux passes : rails, puis signalisation

Les rails sont prioritaires. Pendant une passe RAILS, le train construit exclusivement les rails du lot de chantier et conserve les signaux, chain signals et arrêts correspondants comme ghosts. Les accessoires ferroviaires ne sont pas activés progressivement derrière lui.

Un manque de rails déclenche un retour de ravitaillement et la reprise de cette même passe RAILS. Il ne déclenche jamais le passage à la signalisation. Cela évite de fermer avec des sens uniques une boucle dont les derniers rails attendent encore leurs matériaux.

Une fois la continuité ferroviaire réelle du lot obtenue et un trajet praticable pour desservir ses accessoires puis sortir ou revenir au dépôt vérifié, la machine engage une passe ACCESSORIES. Elle parcourt les rails déjà posés et construit uniquement les accessoires au contact de ses outils latéraux. Les arrêts sont également différés, afin de ne pas annoncer prématurément un nouveau point de destination aux trains de production.

Le lot est une unité de travail locale suivie par le mod, pas toute la planète. La présence de nouveaux ghosts de rails ailleurs ne doit pas empêcher éternellement la finition d’un lot terminé. La délimitation légère des lots utilise les frontières et leur filiation durant la progression ; elle doit être éprouvée sans transformer cette fonction en pathfinder global sur les ghosts.

La séparation en deux passes ne prouve pas à elle seule qu’une signalisation future autorise toutes les manœuvres. Avant de construire un signal, vérifier que la suite du parcours et la sortie restent compatibles avec son orientation. Sur une impasse, un signal interdisant le recul reste ghost tant qu’une sortie sûre n’existe pas, ou est posé au passage de la tête de queue après dégagement complet si cette opération a été démontrée. Pas de franchissement manuel d’une interdiction ni de destruction de signaux existants.

La recette de qualification principale devient : interrompre la construction d’une boucle faute de rails, revenir au bâtiment, se ravitailler, terminer la boucle, puis seulement effectuer la passe de signalisation. La vérification porte également sur les deux têtes et les branches adjacentes non parcourues.

## 12. Embranchements et manœuvres

Quand plusieurs prolongements ghost correspondent au joint touché, choisir un ordre déterministe : poursuite la moins déviée si elle est identifiable par la géométrie moteur, puis ordre stable de nom, position et direction. L’optimalité globale n’est pas recherchée. La symétrie des deux têtes permet de travailler dans les deux sens ; elle ne dispense pas du dégagement complet au niveau des aiguillages.

Les prolongements non choisis restent des frontières disponibles mais ne sont pas affectés à un autre train tant que la zone de manœuvre est occupée par le premier.

À la fin de la branche A :

1. identifier une destination de dégagement sur rails réels en amont du branchement ;
2. prévoir une longueur de dégagement suffisante pour le train complet, calculée depuis ses véhicules réels ;
3. reculer par la conduite automatique native ;
4. confirmer que tous les véhicules ont libéré le joint et ses branches ;
5. planifier une nouvelle approche de B avec la tête active choisie dans le bon sens ;
6. réserver B puis reprendre.

Une pile de branches personnelles peut améliorer la localité, mais les frontières restent l’autorité partagée. Les entrées supprimées ou déjà terminées deviennent simplement caduques.

Pas de dégagement possible, signalisation interdisant le recul ou absence de traction inverse : chantier suspendu et motif explicite. Ne pas prétendre que deux locomotives suffisent à rendre toutes les topologies accessibles.

Les boucles réelles et jonctions construites par d’autres trains sont prises en compte par le pathfinder natif. Une liste visitée (frontière, génération) et la progression réelle empêchent les oscillations sur les circuits sans travail.

## 13. Dépôt, ravitaillement et carburant

Chaque dépôt possède un profil de chargement par item et qualité. Valeurs proposées : 800 rails, 100 signaux, 100 chain signals, 20 arrêts, à ajuster selon la capacité réelle. Les objectifs irréalisables sont signalés avant départ ; pas d’attente infinie sur un chargement qui ne tient pas dans les slots filtrés disponibles.

Le train revient si le prochain élément ne peut plus être payé, si sa réserve de carburant passe sous le seuil configuré, si aucun travail compatible ne reste ou si le joueur ordonne un rappel.

Au quai :

- vérifier le bon arrêt par identité d’entité, pas seulement son nom ;
- vérifier train immobile, intégralement dans la voie de service et affecté à ce dépôt ;
- transférer les objets jusqu’aux objectifs sans dépasser les filtres et limites du cargo ;
- alimenter séparément les inventaires de carburant des locomotives selon un profil de combustible autorisé ;
- ne jamais utiliser une simple agrégation des inventaires du train pour remplir le fuel ;
- gérer les résidus de combustible avec un emplacement de déchargement ou un motif de blocage ;
- ne pas vider automatiquement les autres objets transportés par le joueur.

Première politique de départ : tous les objectifs déclarés obligatoires doivent être atteints, avec une indication de l’objet manquant. Le joueur peut désactiver une ligne inutile à son chantier. Un manque de signaux ne doit pas provoquer des allers-retours incessants pour une frontière contenant seulement des rails.

La réserve de carburant est une politique de seuil énergétique configurable, pas une garantie mathématique de distance aller-retour. Le trajet réel, la congestion et les carburants moddés rendent une telle garantie illusoire. Le contrôle vérifie une traction alimentée dans les deux sens et rappelle le train avant épuisement selon le seuil. Une absence totale de carburant sur le réseau produit une alerte, jamais un ravitaillement à distance.

Le stock du dépôt est un vrai inventaire accessible aux bras. La première version n’ajoute pas de réseau logistique spécial. Chaque quai appartient à un seul train. Les différentes machines partagent le réseau extérieur selon la signalisation native, mais reviennent chacune à leur propre bâtiment ; le joueur organise les raccordements.

## 14. Réservation aux trains et interaction avec les robots

### 14.1 Activation conditionnée par les bâtiments

Le réglage « Réserver l’infrastructure ferroviaire aux trains » est porté par chaque bâtiment réel opérationnel. Valeur proposée à sa première pose : activé. Il est désactivable à tout moment, indépendamment de la pause de son train. Sans bâtiment, aucune exclusion ne s’applique, même si le mod est installé.

Le périmètre demandé est l’ensemble des ghosts des types ferroviaires pris en charge, appartenant à la même force et situés sur la même surface. Aucun rayon autour du dépôt ; aucune influence sur une autre force, une autre surface ou les bâtiments génériques. Les éléments non pris en charge, notamment surélevés au premier périmètre, restent disponibles pour les robots.

Un état commun par couple (force propriétaire, surface) agrège les demandes :

    exclusion_demandée = nombre_de_bâtiments_réels_opérationnels_avec_option_activée > 0

Un train peut être en pause, attendre des matériaux ou être endommagé sans modifier implicitement le choix du joueur : tant que le bâtiment existe, son option reste désactivable et son état dégradé est affiché. Un bâtiment fantôme ou une pose échouée ne compte pas.

- Passage 0 → 1 : lancer la réservation progressive des ghosts ferroviaires existants et traiter immédiatement les nouveaux ghosts éligibles.
- Tant qu’au moins une demande reste active : conserver la politique commune. Désactiver un bâtiment ne peut pas libérer des ghosts que les autres demandent encore de réserver.
- Passage 1 → 0, par désactivation ou retrait/destruction du dernier bâtiment concerné : cesser toute nouvelle réservation et restituer les ghosts déjà réservés.
- S’il reste des bâtiments mais que tous ont décoché l’option : mode partagé, robots et trains autorisés.
- Pose d’un deuxième bâtiment : créer son deuxième train ; ne pas réinitialiser la réservation ni regénérer la machine du premier.

La GUI affiche le nombre de bâtiments qui maintiennent l’option et distingue OFF, ENABLING, ON et RELEASING. Le joueur doit savoir si une désactivation locale laisse une autre demande active.

### 14.2 Mise en œuvre proposée avec de vrais ghosts

L’API examinée ne fournit pas de commutateur individuel documenté pour retirer un ghost de la file des robots. La piste éprouvée conserve le vrai ghost en le transférant dans une force technique sans robots ni réseaux logistiques. Le mod enregistre sa force propriétaire initiale séparément. La force technique doit être mutuellement amie de sa seule force propriétaire pour préserver la copie native de blueprint dans le cas testé ; voir la section 3.8.

La sonde initiale confirme seulement un cas de base : les robots d’un roboport construisent le ghost témoin de leur force et laissent intact le ghost transféré pendant les mêmes 3 600 ticks. Les prochains départs des robots personnels, les opérations d’édition et le cycle complet d’activation/désactivation restent à qualifier. Un robot déjà envoyé avant l’activation peut terminer sa pose : ce comportement est explicitement accepté.

Séquence d’activation pour chaque ghost éligible :

1. relire l’état commun et sa génération pour éviter une réservation après désactivation ;
2. enregistrer l’identité propriétaire puis transférer le vrai ghost à la force technique ;
3. conserver ses paramètres et connexions dans la mesure permise par le moteur ;
4. au moment de construire, prélever le coût dans le wagon central ;
5. dans le même gestionnaire synchrone, replacer le ghost dans sa force propriétaire et le réanimer ;
6. si la pose échoue, restituer les objets et remettre le ghost dans la force technique seulement si l’exclusion est toujours demandée.

L’indexation de tous les ghosts existants est progressive et budgétée pour les megabases ; ne pas annoncer une activation instantanée sur une carte non indexée. Pendant ENABLING, les ghosts pas encore traités peuvent encore être construits par les robots. Le traitement des nouveaux ghosts doit avoir lieu dans leur événement de création lorsque c’est possible.

La désactivation cesse immédiatement les nouvelles réservations, puis restitue les ghosts encore valides à leur propriétaire, avec leurs réglages. RELEASING indique le nombre restant et revient à OFF à la fin. Une nouvelle activation pendant cette restitution incrémente la génération et réconcilie chaque tâche avec la politique actuelle ; aucune file périmée ne doit gagner.

Il n’y a pas d’outil de sélection obligatoire ni d’action manuelle de libération lors du retrait normal du dernier bâtiment : ce retrait déclenche automatiquement la restitution. La sélection par zone ne fait pas partie du premier périmètre demandé.

### 14.3 Critères bloquants de cette option

Tester l’absence d’effet sans bâtiment, la pose réelle contre le ghost de bâtiment, les activations/désactivations successives, deux bâtiments sur une surface, les autres surfaces/forces, le retrait du dernier bâtiment, les sauvegardes durant ENABLING/RELEASING et les robots personnels ou déjà en route.

Tester également copier/coller, minage et annulation de ghost, déconstruction, upgrade, super-forçage, export/import blueprint, fils des signaux et gares, configurations, qualités, multijoueur et fusion de forces.

Un robot déjà en route à l’activation peut terminer son travail. Aucun mécanisme d’annulation ou de récupération forcée de ce robot n’est demandé. Le critère est l’absence de nouveaux départs pour les ghosts déjà pris en charge par la réservation ; les réanimations réalisées par les robots en route sont réconciliées sans paiement du train.

Le transfert ne doit pas rendre les ghosts impossibles à sélectionner ou supprimer par leur propriétaire. Si la force technique casse ces usages natifs, cette implémentation est rejetée. L’amitié mutuelle entre propriétaire et force technique a été vérifiée pour la copie native et les robots de réseau ; elle reste à qualifier pour les robots personnels et les autres actions d’édition.

La fonction est demandée mais n’est pas déclarée techniquement acquise sur la seule base de la sonde. Si la piste échoue aux critères, demander un arbitrage sur une autre représentation ou une demande d’API à Wube ; ne pas livrer un interrupteur sans garantie réelle.

Avant de retirer complètement le mod, attendre la fin de la restitution déclenchée par la désactivation ou le retrait des bâtiments. Retirer le mod alors que des ghosts appartiennent encore à la force technique empêche le script de terminer leur libération.

## 15. États du travailleur

| État | Entrée et travail | Sortie |
| --- | --- | --- |
| SPAWNING | Pose valide du bâtiment et création transactionnelle de ses trois véhicules | VALIDATING après succès complet, sinon rollback de la pose |
| MACHINE_DAMAGED | Composant perdu ou composition scindée ; aucune régénération automatique | Réparation explicite et revalidation au bâtiment |
| VALIDATING | Contrôles composition, quai, contrôle joueur | LOADING ou BLOCKED |
| LOADING | Transferts réels au quai | IDLE_READY quand objectifs atteints |
| IDLE_READY | Attend une frontière atteignable | APPROACHING après claim |
| APPROACHING | Planning sur rails réels | ALIGNING à l’arrivée |
| ALIGNING | Stabilité et contact de l’outil | BUILDING_RAILS ou BUILDING_ACCESSORIES selon la passe, sinon BLOCKED_CONTACT |
| BUILDING_RAILS | Transaction de pose d’un rail, accessoires différés | ADVANCING, RETURNING pour ravitaillement ou BLOCKED |
| BUILDING_ACCESSORIES | Lot ferroviaire réel desservable, trajet de finition sûr | Pose d’accessoires au contact puis RETURNING |
| ADVANCING | Déplacement vers le nouveau rail réel | ALIGNING après progression |
| RETREATING | Dégagement pour une autre branche | APPROACHING après dégagement |
| RETURNING | Trajet au quai et accessoires différés au contact | LOADING |
| PAUSED_BY_PLAYER | Le joueur a repris la main | Réactivation explicite, puis VALIDATING |
| BLOCKED | Motif, prochain réveil et action utile | Événement pertinent, réessai espacé ou action joueur |
| RECOVERING | Attelage, migration ou référence invalidée | VALIDATING après reconstruction |

Motifs distincts : matériel manquant, carburant, composition fixe incomplète, tête active non alignée, contact absent, obstacle, retour interdit, voie occupée durablement, dégagement insuffisant, ghost disparu, géométrie non prise en charge, budget pathfinder épuisé, dépôt supprimé, matériel détruit.

Ne pas supprimer une réservation de circulation applicative alors que son train continue son approche. Les transitions d’annulation doivent d’abord arrêter ou détourner proprement le travailleur.

## 16. Événements et cycle de vie

| Événement ou hook | Responsabilité |
| --- | --- |
| on_init | Initialisation et indexation progressive |
| on_configuration_changed | Migrations versionnées, reprise et réconciliation |
| on_load | Références locales seulement |
| on_built_entity, on_robot_built_entity, script_raised_built, script_raised_revive | Enregistrement des ghosts, rails, dépôts et véhicules ; filtrage et idempotence |
| on_entity_died | Retrait d’entités et réconciliation locale incluant les ghosts de reconstruction éventuels au tick suivant |
| on_player_mined_entity, on_robot_mined_entity, script_raised_destroy | Invalidation locale |
| on_object_destroyed | Nettoyage garanti des objets enregistrés |
| on_train_created | Reconstituer les travailleurs après attelage/séparation ; ne pas réutiliser aveuglément les anciens IDs |
| on_train_changed_state | Réveiller l’automate, sans déduire seul le contact |
| on_train_schedule_changed | Détecter une reprise de planning hors garde de mutation |
| on_player_driving_changed_state et contrôles périodiques ciblés | Suspendre quand un joueur conduit ; vérifier également les modes de contrôle distant applicables |
| on_player_rotated_entity, on_player_flipped_entity, on_blueprint_settings_pasted | Salir le voisinage d’un ghost ou réglage modifié |
| on_pre_ghost_upgraded, on_pre_ghost_deconstructed | Invalider l’ancienne géométrie puis réconcilier au tick suivant |
| on_entity_cloned, on_surface_imported | Enregistrer les nouvelles entités sans recopier des réservations |
| on_pre_surface_deleted, on_surface_deleted, on_surface_cleared, on_chunk_deleted | Annuler travaux et nettoyer index/claims |
| on_forces_merging, on_forces_merged | Suspendre, remapper propriétaires et forces techniques, puis réindexer |
| on_player_setup_blueprint et événements de GUI | Conserver la configuration du dépôt par tags et gérer l’interface |
| on_runtime_mod_setting_changed | Recalculer budgets ou politiques sans reconstruction globale synchrone |

Enregistrer on_tick seulement pour la petite file de tâches qui l’exige ; utiliser on_nth_tick pour les travailleurs arrêtés, transferts et dispatch. Les noms et champs exacts des événements seront vérifiés contre le JSON de la version minimale retenue.

La destruction d’un dépôt ne supprime jamais le fret des trains. Le stock réel du container doit suivre le minage et la destruction natifs ; une GUI ne doit pas le dupliquer dans un inventaire script.

## 17. GUI, configuration et diagnostic

Interface du bâtiment : inventaire natif, quai intégré, objectifs par item/qualité, combustible et seuil, son unique train et les motifs de blocage. Actions : activer la mission, pause, rappeler, centrer sur le train, réindexer. Réglage distinct « Réserver l’infrastructure ferroviaire aux trains », avec état commun de la force/surface, bâtiments qui maintiennent la demande et progression de réservation/restitution.

Interface du train, accessible depuis chacun de ses trois composants : état commun, dépôt, prochaine frontière, matériaux manquants, validité de la composition fixe et tête active. Le wagon central conserve l’accès à son inventaire. L’activation autonome est explicite.

Vue chantiers : frontières accessibles, en approche, en travail, isolées et bloquées, avec train propriétaire et dernier progrès. Les nombres sont ceux de l’index parcouru ; pendant l’indexation initiale, afficher que le comptage est partiel.

Le réglage d’exclusion des robots est disponible dans les bâtiments seulement après qualification de cette fonction. Aucun menu global ne l’active en l’absence de bâtiment. Le mode partagé et les transitions restent identifiables.

Surbrillance facultative : joint visé, surface de contact de l’outil, ghost retenu, accessoires différés. Ces rendus sont temporaires et consultatifs. Aucun cercle présenté comme portée de construction.

Configuration copiée par blueprint : objectifs, orientation logique et réglage d’exclusion ; pas les IDs de trains, jetons de génération, entités, claims ou stocks. Le ghost du bâtiment n’a aucun effet sur les robots. Sa construction réelle génère sa nouvelle machine indépendante une seule fois, avec le réglage copié.

Localisation française et anglaise, identifiants et commentaires de code en anglais selon le socle commun. Textes de diagnostic destinés au joueur, sans traces de pile dans le flux normal.

## 18. Performances et déterminisme

Budgets initiaux à mesurer, et non performances promises :

| Travail | Budget global de départ |
| --- | --- |
| Indexation initiale | 1 à 2 chunks par tick de traitement |
| Réconciliation locale | 128 candidats maximum par tranche ; curseur durable |
| Contrôle des travailleurs actifs | Répartition sur 10 ticks, sans balayage des trains du monde |
| Dispatch | 1 requête pathfinder tous les 15 ticks, 16 objectifs maximum |
| Pathfinder | 4 096 étapes initiales, escalade plafonnée et espacée |
| Pose | 1 rail par travailleur par cycle, sous budget global |
| Transferts | 1 cycle par quai toutes les 30 ticks ; nombre de slots borné |
| GUI | Toutes les 30 ticks, seulement fenêtres ouvertes et données modifiées |
| Réconciliation lente | File tournante, sans rescanner toute la surface |

Le dépassement d’un budget reporte le travail : ne jamais abandonner silencieusement le reste d’un gros blueprint. Une recherche locale renvoyant un grand tableau peut déjà coûter cher ; subdiviser les recherches par zone/type et utiliser les limites de l’API lorsque possible.

Clés canoniques pour recherche directe des ghosts à une position d’extension. Les appels get_rail_extensions sont mis en cache par rail/prototype/fin tant que le voisinage est inchangé. Les caches de trajet ont un TTL et une révision de monde ; les résultats d’occupation dynamique ne sont pas pérennes.

Aucun tri sur l’ensemble du réseau à chaque dispatch. Les travailleurs sont servis en rotation ; un chantier distant finit par être essayé malgré une activité permanente à proximité. L’absence de candidat ne provoque pas un nouveau pathfinding chaque tick.

Mesures : temps script total, coût par worker, nombre de requêtes, steps_count, taille des files, temps d’indexation, poses par minute et coût à l’arrêt. Comparer le même scénario sans mod, mod sans tâche, puis mod actif, sur la même machine et sauvegarde. Un objectif chiffré en millisecondes sera fixé après la phase de mesure.

Tout choix est déterministe : ordre stable des frontières et items, pas d’heure système, pas de dépendance à pairs pour arbitrer une égalité, aucune mutation conditionnée à la présence d’une fenêtre locale. La sauvegarde ne conserve pas une position éphémère comme preuve durable de contact.

## 19. Cas limites et politique

| Situation | Comportement |
| --- | --- |
| Ghost isolé | Indexé, non dispatché ; devient candidat après raccordement réel |
| Signal sur une branche non parcourue | Reste ghost |
| Croisement sans connexion | Aucun prolongement ni accessoire par simple intersection |
| Rails de couches différentes | Pas d’association ; surélevé exclu initialement |
| Arbre, roche, falaise, eau | Blocage ; terrain à préparer par le joueur ou les bots |
| Terrain seulement planifié par tile ghosts | Aucun remblai automatique |
| Ghost construit par un bot | Revalidation, progression sur le rail réel sans consommation |
| Ghost supprimé ou remplacé | Annuler la génération de frontière et la transaction non engagée |
| Matériaux manquants | Retour au dépôt si possible, sinon alerte |
| Qualité absente | Ne pas consommer une autre qualité arbitrairement |
| Train scindé ou attelé | Invalidation du planning de mission et des claims, reconstruction |
| Un composant de la machine détruit ou détaché | Arrêt de construction et d’automatisation, fret restant conservé ; remise en service seulement après reconstitution des trois éléments |
| Joueur au contrôle | Suspension immédiate des nouvelles commandes |
| Train bloqué au rouge | Attente native, pas de contournement manuel |
| Branche trop courte pour une manœuvre | Diagnostic de dégagement ; pas de train téléporté |
| Tête active différente de celle planifiée | Revalidation du sens d’approche et du contact ; les deux têtes sont équipées, aucun refus fondé uniquement sur le choix de l’extrémité |
| Rail détruit sous la mission | Annuler route et rechercher un retour réellement possible |
| Réseau déconnecté du dépôt | Alerte et arrêt ; aucun ravitaillement à distance |
| Bâtiment retiré ou détruit | Retrait de sa machine même éloignée, contenus déposés localement ou en récupération persistante ; aucun doublon et restitution des ghosts si dernière demande |
| Fusion de forces | Suspension et remappage avant reprise |
| Retrait d’un mod de prototypes | Migration qui invalide les tâches inconnues et restitue les ghosts réservés lorsque possible |
| Retrait du mod de chantier | Libération préalable des ghosts techniques ; comportement natif des items retirés à documenter |
| Script externe sans événements | Réconciliation lente et bouton manuel |
| Train-Foundry / STC | Pas de dépendance ; la machine est exclusivement générée par son propre bâtiment, sans inscription de trains extérieurs ni partage d’autorité sur le planning |
| Space Exploration et autres surfaces | Aucune compatibilité annoncée avant qualification de leurs rails et contraintes de surface |

## 20. Découpage des fichiers

    info.json
    settings.lua
    data.lua
    data-updates.lua                 # seulement si compatibilité réellement nécessaire
    control.lua                     # enregistrement des événements et délégation
    prototypes/
      construction-locomotive.lua
      construction-wagon.lua
      depot.lua
      depot-stop.lua
      items.lua
      recipes.lua
      technology.lua
      gui-styles.lua
    scripts/
      constants.lua
      storage.lua                   # schéma, migrations, invariants
      events.lua                    # normalisation des événements et gardes
      registry.lua                  # ghosts, rails, dépôts, objets détruits
      geometry.lua                  # clés canoniques et transformations
      rail-adapter.lua              # extensions et géométries supportées
      contact.lua                   # outils des deux têtes et du module central
      accessories.lua               # ancrages, contact et signaux différés
      frontiers.lua                 # frontières et chunks sales
      dispatcher.lua                # sélection équitable et pathfinder natif
      claims.lua                    # autorité et générations
      worker.lua                    # automate
      navigation.lua                # planning privé, objectifs, retour, dégagement
      construction.lua              # transaction et revive
      inventory.lua                 # qualité, factures, remboursements
      depot.lua                     # un bâtiment, une machine, quai et chargement
      machine-factory.lua           # génération idempotente et cycle de vie des trois véhicules
      bot-reservation.lua           # fonction optionnelle, après qualification
      gui.lua
      diagnostics.lua
    migrations/
    locale/fr/
    locale/en/
    graphics/
    tests/
      unit/
      engine/
      benchmark/
      visual/
    docs/
      LLD.md
    specs/
      README.md
      001-construction-train.md
    build.sh

Ces modules peuvent être regroupés au début si leur taille ne justifie pas un fichier. Ne pas créer un framework, une couche RPC ou une classe par état. Tous les require ont lieu au chargement, pas dans les callbacks.

build.sh suit les voisins : test, package, devlink, unlink, clean. Aucun zip ni remplacement de mod actif effectué à la main. Les tests utilisent un profil et des mods temporaires ; ils ne changent ni la mod-list du joueur ni ses sauvegardes.

## 21. Stratégie de validation

### 21.1 Tests purs

Clés canoniques, qualités, choix d’alternative de placement, rollback partiel, ordonnancement équitable, générations de claims, transitions d’état et transformations de contact. Les tests ne prétendent pas remplacer la géométrie et la circulation du moteur.

### 21.2 Scénarios moteur obligatoires

- E01 : voie droite dans les quatre directions ; composition locomotive — wagon — locomotive, contact réel et dix poses successives avec déplacement entre chaque, puis inversion de la tête active et répétition dans l’autre sens.
- E02 : half-diagonal et toutes les orientations de curved-rail-a / curved-rail-b ; même preuve, sans élargir arbitrairement le contact.
- E03 : signal et chain signal de chaque côté ; contre-exemple sur une branche voisine et croisement non connecté.
- E04 : arrêt sur chaque orientation autorisée ; rattachement du vrai arrêt égal à l’ancrage attendu.
- E05 : bifurcation en Y, branche A puis dégagement complet puis B ; train fixe de trois véhicules et branche trop courte pour le dégagement.
- E06 : boucle planifiée, rupture de stock pendant la passe rails, retour et recharge, reprise sans signalisation prématurée puis finition des accessoires au contact sur parcours sûr.
- E07 : signal rouge réel et train de production ; aucune collision provoquée par une commande manuelle du mod.
- E08 : deux travailleurs visant la même frontière ; un seul paiement et une seule pose.
- E09 : robot qui construit entre affectation et arrivée ; aucun paiement en double.
- E10 : inventaire insuffisant ou filtré, courbe coûtant plusieurs objets, qualités mélangées et alternative de placement.
- E11 : obstacle ou ghost supprimé juste avant revive ; objets restitués exactement.
- E12 : événement de revival provoquant une invalidation externe ; transaction et récupération cohérentes.
- E13 : fuel absent dans un sens, résidus saturés, retour avec réserve basse et dépôt vide.
- E14 : sauvegarde/rechargement dans chaque état durable ; pas de dérive d’ID ni de duplication.
- E15 : minage, mort, attelage, séparation, clone, suppression de chunk/surface et fusion de forces.
- E16 : prise de contrôle joueur et modification du planning ; pas de lutte entre mod et joueur.
- E17 : exclusivité conditionnée par un bâtiment réel, bascule activé/désactivé, dernière demande et bâtiments multiples, séparation force/surface, prochains départs des robots fixes/personnels, pose autorisée aux robots déjà en route, édition complète des ghosts, blueprints et restitution de force.
- E19 : pose réelle contre ghost de bâtiment, création exacte d’un train par bâtiment, rollback de pose obstruée, deux bâtiments et deux machines distinctes, sauvegarde/rechargement sans duplication.
- E20 : récupération du bâtiment avec train éloigné/coincé/endommagé, dépôt local exact des contenus, absence de génération ou double remboursement, traitement d’un occupant et restitution automatique des ghosts à la dernière désactivation.
- E18 : multi-joueur et replay déterministe, avec plusieurs dépôts et interfaces ouvertes.

Chaque scénario doit produire une preuve exploitable : journal d’assertions, positions, quantités initiales/finales et état attendu. Pour le contact, enregistrer la position de l’outil, le joint, le rail desservi et la position du train à chaque pose.

### 21.3 Performances

Sauvegardes synthétiques : 10 000, 100 000 puis 1 000 000 de ghosts, plusieurs surfaces/forces, 1/10/50 travailleurs, beaucoup de branches, réseau sans travail et milliers de frontières inaccessibles. Séparer coût d’initialisation et régime permanent. Vérifier que le coût à l’arrêt dépend des files actives et non de la taille de toute la carte.

### 21.4 Visuel et livraison

Chargement réel de tous les prototypes avant livraison, vérification GUI et console sans erreur. Vue de l’outil sur droit et courbe, sens des locomotives, arrêt au quai, animation de pose et diagnostics. Le seul contrôle de syntaxe Lua n’est pas une validation de mod.

Essais de compatibilité dédiés pour les gros packs choisis, avec lecture de leurs recettes et technologies réelles. Aucune annonce globale « tous les mods ferroviaires » à partir d’un test vanilla.

## 22. Phases d’implémentation et conditions de passage

### Phase 0 — preuves moteur ciblées

Trois preuves courtes et indépendantes : réservation réversible des ghosts pour les prochains départs de robots ; progression sur droites/courbes/semi-diagonales avec contact réel, retour du même train et reprise par l’autre tête ; boucle interrompue faute de matériaux, ravitaillement et finition avant signalisation.

La première sonde du 30 octobre a invalidé le point frontal rigide. La seconde valide un modèle de bras articulé borné avant chacune de 352 poses sur huit tracés, avec courbes et inversion des deux têtes. Une sonde distincte valide la réservation/libération des ghosts pour les robots de réseau et un dépôt local exact des contenus avant retrait des trois véhicules. Huit profils supplémentaires valident ensuite une boucle interrompue faute de matériaux, le ravitaillement, sa finition, deux accessoires différés et le retour réel. L’intégration aux bâtiments finaux, les robots personnels et l’ensemble des actions d’édition des ghosts restent à qualifier. La copie native impose la variante de force technique amie, vérifiée pour les robots de réseau. Pas de GUI finale ni d’assets définitifs à ce stade.

DoD : preuves moteur E01/E02, partie réversibilité de E17 et scénario E06, avec mesure du contact ; chaque limitation est explicitée.

### Phase 1 — une machine complète et utilisable

Un bâtiment génère une seule machine fixe ; stock central, chargement réel, passe RAILS, ravitaillement, passe ACCESSORIES au contact, retour au bâtiment et réglage d’exclusion planétaire. GUI minimale de commande et diagnostic.

Inclure dès cette phase les sauvegardes/rechargements et la récupération du bâtiment et de sa machine, même éloignée ou endommagée. Ce ne sont pas des finitions reportées après l’ajout des flottes.

DoD : un joueur pose le bâtiment et un blueprint de boucle, la machine termine le chantier en deux passes, se recharge et peut être retirée sans perte ni duplication. E01 à E04, E06, E10/E11, E13/E14, E17, E19 et E20 passent dans ce périmètre.

### Phase 2 — embranchements et plusieurs bâtiments

Deux bâtiments génèrent deux machines distinctes, chacune rattachée au sien. Ajouter dispatch équitable, claims, dégagement d’aiguillages et gestion de leurs lots, sans double paiement. L’exclusion des robots reste commune à la même planète/force tant qu’au moins un bâtiment la demande.

DoD : E05, E07 à E09, E15/E16 et E18 passent ; chaque machine finit ses lots et revient à son bâtiment sans s’approprier la machine voisine ni bloquer indéfiniment la finition de l’autre.

### Phase 3 — graphismes, interface et performances

Transformer la [référence visuelle conservée](concepts/train-depot-v1.png) en véritables sprites adaptés à Factorio : transparence, ombres, orientations du train, articulations et outils animés. L’image de concept n’est pas déjà un sprite exploitable. Comparer des captures dans le jeu au zoom habituel avant de juger la fidélité.

Finaliser GUI, diagnostics, indexation progressive et benchmarks de grandes cartes. DoD : tests visuels moteur, fichiers et prototypes chargés sans erreur, files bornées et mesures comparées au témoin. La qualité visuelle est évaluée dans le jeu, pas sur la seule planche concept.

### Phase 4 — diffusion

Équilibrage des recettes, traductions, documentation finale, éventuels essais de compatibilité choisis et paquet reproductible. L’image de référence peut illustrer la genèse du projet mais doit être légendée « concept » si elle n’est pas une capture réelle.

DoD : paquet installé dans un profil propre, tests appropriés verts et limites documentées. Version et changelog suivent les règles communes ; aucune publication implicite.

## 23. Décisions proposées et questions réellement ouvertes

Choix de composition demandé par Geoffrey : machine fixe locomotive — wagon — locomotive. Les autres choix techniques ci-dessous sont proposés pour commencer :

- machine complète de composition fixe : locomotive — wagon central — locomotive ;
- outils de chantier aux deux extrémités, avec un seul stock dans le wagon central ;
- aucun wagon cargo supplémentaire ni composition personnalisable ;
- traction bidirectionnelle requise pour les missions autonomes en impasse ;
- conduite et pathfinding natifs, progression initiale arrêt par arrêt ;
- index spatial de ghosts et frontières locales plutôt que graphe de tout le futur réseau ;
- rails au sol vanilla pour la première version ;
- bâtiment avec arrêt intégré, posé sur une voie de service préparée ;
- génération automatique d’un unique train à la pose réelle, un bâtiment par machine ;
- exclusion des robots activée par les bâtiments et désactivable, agrégée par force/surface ;
- mode partagé sans bâtiment ou lorsque toutes les demandes d’exclusion sont désactivées ;
- deux passes par lot : rails avec ravitaillement éventuel, puis accessoires quand un parcours de sortie sûr est disponible ;
- robots déjà en route autorisés à terminer ; exclusion des prochains départs sur toute la planète pour la force concernée ;
- récupération du bâtiment et retrait de sa machine où qu’elle soit, contenus conservés localement ;
- matériaux exacts et qualités conservées.

Questions de conception qui demandent une preuve moteur, pas une réponse inventée :

- Le modèle articulé validé sur les huit tracés doit encore être qualifié sur les aiguillages, croisements et cas limites, puis matérialisé dans les graphismes.
- La navigation native permet-elle l’alignement et le dégagement nécessaires sans conduite manuelle ?
- La passe d’accessoires après la finition ferroviaire permet-elle une desserte au contact et une sortie sûre pour toutes les géométries prises en charge ?
- L’adaptateur d’arrêt peut-il prouver son ancrage avant revive dans chaque orientation admissible ?
- La force technique amie préserve la copie native dans le cas testé ; les autres actions d’édition et les robots personnels doivent encore être qualifiés.

Le nom commercial, l’apparence de la machine et les dosages de recettes restent faciles à ajuster. Aucun de ces choix esthétiques ne doit masquer les preuves mécaniques attendues de la phase 0.

## 24. Référence visuelle

[Planche de référence conservée](concepts/train-depot-v1.png), [contexte](concepts/README.md) et [consigne de génération](concepts/train-depot-v1.prompt.txt). Concept retenu le 30 octobre 2026 pour guider les graphismes et la documentation ; il ne représente pas encore le rendu intégré au jeu.

## 24. Premier prototype intégré — 30 octobre 2026

Le runtime est dans `scripts/`, les prototypes dans `prototypes/` et les locales dans `locale/`. Le guide d’installation et les limites actuelles sont dans le [README](../README.md). Le dépôt exige pour ce prototype une voie nord-sud préparée et un placement à droite. Les graphismes utilisent des modèles vanilla provisoires ; le concept conservé ne représente pas le rendu actuel.

`./build.sh test` exerce le mod réellement chargé dans Factorio 2.1.24 : génération unique locomotive–wagon–locomotive, découverte de la boucle depuis les ghosts, 52 rails et trois accessoires construits et payés, rupture de stock, ravitaillement, retour, deux bâtiments indépendants, libération de la dernière réservation et retrait éloigné avec comptage des contenus. Une vraie sauvegarde en mission est ensuite rechargée et termine le même scénario. La fixture définit le chantier ; elle ne fournit pas d’itinéraire au runtime.

Les tests ciblés et leurs mutations vérifient les protections contre la suppression d’un composant détaché occupé, le double remboursement du bâtiment et les blocages sans nouvelle tentative. Le test graphique `python3 tests/visual.py` couvre en complément le panneau natif, un vrai joueur et son roboport, la réservation puis la restitution des ghosts et les événements de retrait. Ses résultats et sa capture sont séparés de ceux du scénario moteur.

Ces preuves ne qualifient pas encore les branches complexes, la concurrence de plusieurs trains sur un même chantier, toutes les orientations des accessoires, la copie des réglages dans les blueprints, les conversions de forces, les performances megabase ou les interactions avec les packs de conversion. Les critères correspondants restent ouverts.

### Correction issue de l’essai utilisateur : carburants

Le premier essai en sandbox a révélé que le chargement imposait du charbon même lorsque les locomotives contenaient un autre combustible valide. Le runtime compte désormais la réserve en énergie, ajoute le combustible déjà en cours de consommation, filtre les catégories acceptées par chaque brûleur et transfère les objets avec leur qualité. Le seuil initial équivaut à 50 charbons par locomotive ; ce n’est plus une obligation de posséder cet objet. Le panneau de chargement indique un déficit de matériau ou d’énergie. Le scénario moteur exerce combustible solide, carburant pour fusée, combustible nucléaire, rejet des piles pour réacteur et comptage du combustible actif. Les carburants des mods sont reconnus par leurs prototypes, sans qualification exhaustive des packs.

### Corrections issues de la sandbox : priorité et manœuvres

Une première reproduction de `ct-debug` est restée à 209 constructions pendant 9 000 ticks. La recherche ne parcourait qu’une page de frontières avant d’autoriser les accessoires. Elle attend maintenant le balayage complet, conserve aussi sa position entre les ancres lorsque les 16 destinations du lot sont remplies et réévalue la priorité des rails avant les trajets d’accessoires. Les tests ciblés et mutations détectent les pages abandonnées et la dernière ancre perdue.

Le retour au dépôt reconnaît deux positions orientées d’accostage qui centrent le wagon devant le même bâtiment. Quand aucune n’est directement accessible, une recherche bornée teste un dégagement sur les rails droits déjà desservis, y conduit physiquement le train, puis réessaie le retour après inversion. Elle conserve le besoin de ravitaillement, utilise le budget de recherche et limite les manœuvres à quatre. Le blocage persistant ne relance plus un nouveau chantier et apparaît dans le panneau. Sur la copie de `ct-debug`, le compteur passe de 209 à 335 constructions en 9 000 ticks, avec un vrai retour au dépôt, chargement et reprise. L’original est conservé ; outils et journaux sont `tools/debug_save.py`, `tools/probes/debug-save.lua` et `docs/debug-save-results.txt`. La réservation et les variantes Py de cette sauvegarde sont conservées, ce qui ne constitue pas une qualification générale de Py.

La puissance des locomotives spécialisées passe de 600 à 2 400 kW et leur freinage de 10 à 40, à vitesse maximale identique. Sur le scénario intégré de 55 poses, l’achèvement passe de 7 170 à 4 830 ticks, soit environ 33 % de temps en moins. Le nombre de ravitaillements passe de un à deux ; ce réglage augmente la consommation. Cette comparaison concerne ce scénario et ne garantit pas le même gain sur tous les réseaux.

### Optimisation de la passe des accessoires — 1er novembre 2026

La sandbox fournie en phase signaux contient 1 206 anciennes entrées de frontières et aucun rail fantôme restant. Leur balayage avant chaque accessoire provoquait une attente répétée de 380 ticks ; les accessoires étaient ensuite sélectionnés par identifiant. Un index des seules frontières actives est désormais mis en cache par force et surface, avec invalidation à l’ajout, au changement et à la suppression d’une frontière. Les changements de domaine, dont la fusion de forces, invalident les caches source et destination. La recherche conserve ses curseurs entre les lots lorsque des rails restent à traiter.

La sélection d’accessoires favorise le contact immédiat, puis les voisins géométriques ; le pathfinder compare leurs accès réels dans les deux sens. Les accessoires déjà au contact sont traités sans trajet supplémentaire. Les travaux différés attendent leur échéance au lieu de provoquer un retour au dépôt ; les réservations sont néanmoins réévaluées pour reprendre dès leur libération. Le contact, le rattachement au bon rail, le paiement et la possibilité de retour continuent d’être contrôlés pour chaque pose. Les poses restent effectuées à l’arrêt.

Sur la même sauvegarde et 9 000 ticks, 13 accessoires sont construits avant correction et 74 après. Le délai médian entre une pose et le départ vers l’accessoire suivant passe de 6,33 secondes à 0,167 seconde ; le maximum après correction sur les échantillons mesurés est de 0,333 seconde. Ces mesures incluent la reprise du ravitaillement dans la passe optimisée ; elles ne mesurent ni un trajet globalement optimal ni une garantie pour toutes les cartes. Les journaux sont `docs/accessories-before.txt` et `docs/accessories-after.txt` ; `python3 tools/compare_accessories.py` contrôle le point de départ, la durée et les gains et écrit `docs/accessory-performance.json`.

### Vérifications avant le premier commit du lot 1

La revue initiale a mis en évidence une reprise manuelle ignorée entre deux déplacements et un remboursement du bâtiment sans sa qualité. Le runtime mémorise désormais son contrôle automatique et distingue ses propres arrêts d’une reprise manuelle du joueur avant toute pose ou nouvelle commande. La qualité du dépôt est conservée lors de sa récupération et d’un refus de placement. Les tests moteur exercent les transitions de pose des rails, de pose et de sélection des accessoires, de chargement et d’attente, ainsi que la récupération et le refus d’un dépôt rare. Quinze mutations vérifient les régressions couvertes. Ces interruptions volontaires font partie du test de sécurité et ne remplacent pas les mesures de performance séparées ci-dessus.

## 25. Premiers scénarios du lot 2 — branches et concurrence

Le test `tests/concurrency.lua` raccorde deux dépôts à une même voie réelle et planifie deux boucles. La sélection et la conduite sont celles du runtime ; le scénario ne donne aucun itinéraire aux trains. Un journal des paiements vérifie l’appartenance de chaque réservation, l’unicité du paiement et le débit exact de l’inventaire.

La variante `concurrency-keep` laisse les deux travailleurs construire jusqu’au retour aux dépôts : 104 rails, 168 objets consommés, 52 constructions par train et 832 rails restants sur un stock initial de 1 000. La variante `concurrency` injecte le retrait du premier au point de paiement, après réservation réelle et avant débit : quatre constructions ont été faites par le premier, puis le second termine les cent autres. La réservation libérée est payée par le survivant ; les contenus récupérés au sol participent au comptage global, et le bâtiment retiré est remboursé une fois. L’exclusion demandée par l’autre dépôt reste active.

Chaque variante crée une vraie sauvegarde lorsque les deux trains ont commencé à travailler, puis la recharge et termine à nouveau ses contrôles. Les géométries natives communes aux trois scénarios sont dans `tests/fixtures/rail_loop.lua` et ne sont copiées que dans les profils temporaires de test. Aucun ajout de ce lot n’est nécessaire au runtime du mod pour ces cas ; les contraintes de circulation et de signalisation des autres réseaux restent à qualifier.

## 26. Révision du 2 novembre 2026 — machine unique et construction en mouvement

L'essai utilisateur à quatre machines sur `ct-debug-2` a révélé une collision sur un accès partagé non signalé. Les réservations de ghosts distincts n'empêchent pas les itinéraires réels de se croiser. La preuve `docs/traffic-before.txt` montre des véhicules distincts qui se poussent et perdent des points de vie. Les anciens scénarios de concurrence ci-dessus constituent des résultats historiques sur une topologie limitée ; ils sont retirés de la suite courante et ne qualifient pas le trafic.

Geoffrey retient une seule machine par planète et force. `factory.conflict` refuse un second bâtiment avant toute génération ; le refus restitue l'objet dans sa qualité au joueur, au robot ou localement au sol. L'événement répété du même dépôt reste idempotent. Les anciennes flottes ne sont ni supprimées ni remboursées automatiquement : les commandes de travail et de rappel sont bloquées, les claims libérés et les trains sans occupant arrêtés. Le retrait reste disponible. Après récupération des bâtiments supplémentaires, un démarrage explicite réactive la machine restante. Les domaines des autres forces et surfaces restent indépendants.

Le runtime conserve son ordonnanceur toutes les dix frames et ajoute un contrôle léger du mouvement à chaque frame. À moins de douze cases d'un joint de construction, la vitesse est seulement réduite si elle dépasse 0,12 case/frame, soit environ 26 km/h. Le contrôleur ne fait jamais accélérer un train arrêté par la conduite native. Dès le contact frontal géométrique, il paie et construit le prochain rail réel, puis prolonge l'itinéraire natif pendant que le train roule encore. Aucun changement de position ni navigation sur les ghosts n'est utilisé. La réduction directe de `LuaTrain.speed` exige des essais réels : l'API avertit que cette écriture affecte les calculs de freinage. La cohabitation avec les trains de production reste à qualifier.

Les accessoires latéraux sont examinés pendant les trajets de chantier et d'accessoires. Une pose au contact ne remplace pas le trajet en cours. Pendant la construction avec des frontières restantes, un signal non apparié à un signal opposé déjà réel est différé : son effet de sens unique porte sur tout un segment, au-delà des rails présents dans un seul trajet du pathfinder. Les signaux appariés restent soumis à un trajet natif vers le dépôt et à un trajet orienté depuis le dépôt vers le front actuel. Les travaux dangereux ou sans matériau sont différés sans interrompre le rail en cours ; les accessoires restants sont traités par la passe dédiée.

Le chargement initial conserve les objectifs complets. Un ravitaillement des rails exige les rails et le carburant, sans attendre des accessoires déjà consommés. Un ravitaillement des accessoires exige le matériau effectivement manquant et le carburant ; les autres objectifs restent des quantités souhaitées, non des conditions de départ pour ce retour.

Les scénarios moteur `engine` et `engine-north` contrôlent le contact de chaque pose, le paiement, le nombre de constructions pendant le mouvement, les deux sens, les retours pour rupture de stock et le rechargement réel. `engine-stop` désactive uniquement le contrôleur de construction en mouvement pour fournir un témoin avec arrêts, et vérifie qu'aucun rail n'y est posé pendant le déplacement. `singleton` teste le refus dans sa qualité, l'indépendance des domaines, une ancienne flotte de quatre machines, les stocks conservés, le refus de démarrer/rappeler et la reprise après récupération des trois dépôts supplémentaires. Les fixtures ne fournissent pas d'itinéraire aux travailleurs.

Mesure sur cette boucle : 5 220 ticks avec arrêts des rails, 3 720 en mouvement, soit 28,74 % de temps en moins (87 contre 62 secondes simulées). Le sens opposé termine en 3 750 ticks. Les deux cas mobiles posent les 52 rails et les trois accessoires pendant le mouvement. Le témoin garde la pose mobile des accessoires. `tools/compare_motion.py` vérifie ces conditions et produit `docs/motion-performance.json` ; les interruptions manuelles et deux ravitaillements font partie des scénarios. Aucun gain général sur tous les réseaux n'est déduit de cette seule mesure.

## 27. Nouveau module orientable avec voie traversante intégrée

La spécification 002 remplace l'exigence de voie préparée pour les nouvelles poses. L'objet historique place maintenant `ct-construction-module`, un `proxy-container` natif à quatre directions, lié au coffre enfant `ct-depot-stock` de cent emplacements. Le principal expose directement cet inventaire et ne possède aucun stock parallèle. `direction_count=4` fournit la rotation native avant pose, puis le runtime la verrouille après génération. L'ancien prototype `ct-construction-depot` reste inchangé dans ses fonctions de stockage et de placement sur une voie préparée, pour charger les sauvegardes existantes ; son `placeable_by` conserve l'objet historique pour ses ghosts.

`scripts/depot.lua` prépare la voie dans le repère cardinal du module. Son centre est aligné sur la grille native des rails ; quinze tronçons couvrent les offsets −14 à +14, avec des raccords sélectionnables aux deux bouts. Les rails créés sont protégés contre le minage et la déconstruction. Les tronçons parallèles déjà présents, de la même force et à la même position, sont réutilisés sans modifier leurs protections ni en devenir propriétaire. La recette du module comprend quinze objets rail ; sa récupération rend le bâtiment, jamais quinze rails supplémentaires.

Le constructeur vérifie les véhicules existants et la pose de chaque nouveau rail et du coffre avant création. Un échec ultérieur du quai ou des véhicules détruit seulement les composants créés pendant cette tentative. Les locomotives, le wagon, le quai et le stock sont placés dans ce même repère. Les deux destinations d'accostage se déduisent de l'axe réel du quai, et la présence au dépôt compare la projection longitudinale, sans calcul réservé à Y.

`I.stock` utilise le coffre enfant pour les nouveaux modules et le bâtiment lui-même pour les anciens dépôts. Le principal expose nativement le même inventaire par son proxy ; le panneau est ancré à `proxy_container_gui`, sans dépendre d'une redirection depuis un inventaire vide. Le marquage au sol est un rendu provisoire, distinct des graphismes finaux. Les décorations sont détruites au retrait ou à l'effacement de la surface.

Le retrait suspend la machine et arrête ses trains avant d'attendre un véhicule tiers présent sur toute la voie interne, rails empruntés compris. Il conserve les occupants et les contenus suivant la récupération existante, retire le coffre, le quai, les véhicules et les seuls rails créés par le module. Les rails empruntés et les raccordements du joueur restent présents. Une panne de composant utilise la même transition centralisée vers l'état endommagé et suspend les trains sans occupant. La nouvelle structure est enregistrée dans `storage.ct` avec ses références natives ; aucun nouveau composant n'est généré au chargement.

`tests/depot_module.lua` exerce les quatre orientations. La passe native `--test-save` vérifie la rotation, la pose depuis le curseur, les deux prolongements, le refus du minage des raccords et le minage du module. Ce mode fournit un joueur sans écran, mais n'écrit pas d'autosauvegarde dans la version examinée ; une passe serveur distincte est donc obligatoire pour créer la vraie sauvegarde de mission et la recharger. Chacune construit 52 rails en mouvement pour 84 objets, effectue deux ravitaillements, vérifie les deux accostages, le retrait différé et la conservation des voies empruntées. La destruction du stock ou d'un rail emprunté pendant un déplacement doit suspendre la conduite et laisser le freinage natif arrêter le train. Huit mutations temporaires réintroduisent les défauts de rollback, de destruction des rails empruntés, de rotation, de trafic tiers sur rails créés ou empruntés, de propriété des rails, d'axe d'accostage et d'arrêt après dommage, avec messages de rejet précis.

`tests/legacy.py` génère une vraie sauvegarde avec les sources immuables du commit `f14769e`, puis remplace uniquement la copie temporaire du mod par les sources courantes. Une version distincte dans cette copie force l'événement natif de changement de configuration, sans modifier `info.json` dans le projet. Le dépôt ancien est en pause ; les identifiants du bâtiment, des véhicules, du quai, du train et des rails, leurs positions, ainsi que chaque emplacement de stock, de carburant et de récupération restent identiques avant et après initialisation. Une nouvelle sauvegarde est produite puis rechargée avec les mêmes assertions. Ce test ne mesure pas une mission de construction de l'ancien dépôt après mise à jour ; les scénarios moteur habituels couvrent séparément son fonctionnement courant.

La fenêtre rendue, l'aperçu graphique au curseur et les graphismes du bâtiment n'ont pas été vérifiés avec un client autonome ; il n'est pas installé. Le test serveur contrôle l'ancrage de la GUI et l'inventaire, mais ne prouve pas l'affichage de la fenêtre native. Aucun client Steam n'est lancé pour compléter cette preuve.
