# Construction Train — premier prototype

Mod local pour **Factorio 2.1.24 ou ultérieur**. Une seule machine de chantier **locomotive — wagon central — locomotive** est autorisée par planète et par force. Son bâtiment orientable génère sa propre voie traversante, son stock, son quai et son train. Le joueur raccorde les deux extrémités au réseau. Le train construit les rails planifiés au contact et pose au passage les accessoires compatibles avec son retour et sa reprise de chantier.

Les graphismes actuels sont provisoires : emprise du module marquée au sol, stock représenté par un grand coffre et véhicules dérivés des modèles vanilla. La [planche concept](docs/concepts/train-depot-v1.png) reste la référence pour les futurs graphismes ; ce n’est pas une capture du prototype.

## Essayer le prototype

1. Activer **Construction Train** dans le menu des mods et redémarrer Factorio.
2. Rechercher **Construction ferroviaire spécialisée**, après la recherche ferroviaire automatisée.
3. Choisir un terrain libre sur terre. Tenir le dépôt en main et utiliser **R avant la pose** pour orienter sa voie nord-sud ou est-ouest ; les quatre directions cardinales sont possibles.
4. Poser le module sans préparer de voie. Il génère quinze rails, deux locomotives, le wagon central, le quai et son coffre de stock. L'objet inclut le coût des quinze rails internes. Un placement invalide est refusé et remboursé dans sa qualité. Une seconde pose sur la même planète pour la même force est refusée.
5. Avec des rails vanilla, prolonger les **deux extrémités sélectionnables** et raccorder le module au réseau dans les deux sens. Aucun raccord extérieur n'est créé automatiquement. La rotation du bâtiment est verrouillée après sa pose.
6. Ouvrir le bâtiment ou son coffre de stock, **y déposer les matériaux et le carburant**, puis régler les objectifs de chargement. Les objectifs ne fournissent pas les objets : valeurs initiales **400 rails, 50 signaux, 50 chain signals, 10 arrêts et une réserve de carburant équivalant à 100 charbons (50 par locomotive)**. Mettre à zéro les lignes inutiles si leurs matériaux ne doivent pas conditionner le départ.
7. Poser un blueprint ferroviaire raccordé à des rails réels accessibles. Le train cherche son chantier et démarre lorsque son chargement est prêt.

Le coffre de stock, visible à côté de la voie interne, est un inventaire natif de 100 emplacements, accessible à la main ou avec des bras. Cliquer sur le bâtiment ouvre ce coffre et le panneau du train. Le wagon central possède son propre stock de 100 emplacements. Le chargement automatique accepte les carburants compatibles avec les locomotives, y compris ceux des mods et leurs qualités. La réserve est comptée en énergie, en incluant le combustible déjà en cours de consommation ; un carburant plus puissant demande moins d’objets. Le panneau indique les matériaux ou la réserve d’énergie manquants au départ.

Les anciens dépôts restent fonctionnels dans leur disposition d'origine : aucun train n'est recréé et aucune voie ne leur est ajoutée automatiquement. Les nouveaux objets posent le module traversant. Ce changement de prototypes exige un **redémarrage complet de Factorio**.

Le panneau permet de démarrer, mettre en pause, rappeler la machine ou récupérer l’ensemble. Les locomotives spécialisées disposent d’une puissance et d’un freinage quadruplés, avec la même vitesse maximale ; leur consommation augmente. Les trajets utilisent le moteur et la signalisation de Factorio : aucune navigation sur les ghosts ni génération de tracé.

## Pose au passage et ravitaillement

Les matériaux viennent du wagon central. Une rupture de stock pendant la pose des rails provoque un retour au quai, un rechargement et la reprise du chantier. Le dépôt accepte les deux sens d’accostage. Si un retour direct est impossible, le train cherche un dégagement sur les rails déjà desservis pour inverser sa marche ; quatre manœuvres au maximum sont tentées, puis un blocage explicite attend une correction du réseau.

Le train prolonge sa destination dès que l’outil atteint le prochain rail, sans imposer un arrêt à chaque pose. La vitesse est limitée à proximité du front de construction ; les trajets sur le réseau existant conservent leur vitesse normale. Des arrêts restent possibles aux embranchements, aux signaux et pendant les manœuvres.

Signaux, chain signals et arrêts sont construits uniquement sur les rails desservis, avec vérification du contact et du rattachement. Les accessoires au contact peuvent être posés pendant le déplacement. Pendant la construction des rails, un signal sans signal opposé déjà réel est différé : il pourrait rendre tout le tronçon à sens unique. Les signaux qui compromettraient le retour ou la reprise depuis le dépôt sont également différés. Les accessoires restants font ensuite l’objet de trajets dédiés ; un sens unique impossible ou une branche trop courte peut laisser des travaux en attente.

Au ravitaillement des rails, l’absence d’accessoires complémentaires ne bloque pas le départ. Au ravitaillement des accessoires, le matériau effectivement manquant reste obligatoire. Le premier départ attend les objectifs configurés.

Un ghost ferroviaire isolé n’est pas un chantier accessible. Les arbres, rochers, falaises, eau et autres obstacles doivent être traités séparément.

## Réserver les rails aux trains

Le réglage du bâtiment concerne les **rails au sol, signaux, chain signals et arrêts pris en charge, sur toute la même planète/surface pour la même force**. Il est activé par défaut après la pose réelle du bâtiment et peut être désactivé.

Dans une ancienne sauvegarde avec plusieurs bâtiments, l’exclusion reste active tant qu’au moins l’un d’eux la demande. Le panneau indique ce nombre. À la dernière désactivation ou au retrait du dernier bâtiment demandeur, les ghosts sont restitués progressivement aux robots. Un robot déjà en route est autorisé à finir sa pose.

Le prototype conserve de vrais ghosts dans une force technique amie de leur propriétaire. La copie native de blueprint, les robots de réseau et les robots personnels ont été exercés. L’édition complète des plans, les fils, les upgrades et les interactions avec d’autres mods restent à qualifier.

**Avant de désinstaller le mod**, désactiver l’option dans tous ses bâtiments ou récupérer ces bâtiments, puis laisser le jeu terminer la restitution. L’indexation et la restitution sont progressives ; leur durée augmente avec la carte. Ne pas retirer le mod alors que des ghosts appartiennent encore à sa force technique.

## Récupération et sécurité

Le bouton de récupération retire aussi les véhicules éloignés, après vérification de tous les composants. Les matériaux et carburants stockés sont déposés près des véhicules ; ils ne sont pas téléportés jusqu’au bâtiment. Un joueur à bord ou un véhicule encore mobile diffère l’opération.

Les rails internes ne sont pas minables séparément. La récupération retire ceux créés par le module et préserve les rails du joueur, y compris des rails déjà présents réutilisés à la pose. Un train tiers sur la voie interne diffère le retrait ; le coffre et le train de chantier ne sont pas supprimés sous le trafic.

Le minage natif et la récupération par script ne remboursent pas deux fois le bâtiment et conservent sa qualité. Une machine endommagée ne génère pas de remplaçante gratuite. Une modification du planning par le joueur ou une prise de contrôle suspend l’automatisation, y compris juste avant une pose.

Une ancienne sauvegarde contenant plusieurs dépôts de la même force sur une planète suspend ces machines et conserve leurs contenus. Récupérer les bâtiments supplémentaires, puis cliquer sur **Démarrer** pour la machine restante. Le rappel est également bloqué pendant ce conflit ; les bâtiments ne sont jamais supprimés automatiquement.

## État de qualification

Le lot 1 a été accepté en sandbox le 1er novembre 2026 : chantier complet rails puis signaux, puis reprise après déconstruction par les robots et restauration du plan. L’essai à quatre trains a ensuite révélé une collision sur un accès sans signaux. Le 2 novembre, la cible devient une machine unique par planète et force avec pose en mouvement.

Le scénario moteur réel exerce la génération unique, la découverte de 52 rails, le ravitaillement, un signal, un chain signal et un arrêt, le retour et le retrait éloigné avec comptage des stocks. Les poses en mouvement sont comptées séparément.

Une sauvegarde créée en cours de mission est rechargée et termine le même scénario. Le test graphique utilise un vrai joueur, les vrais éléments GUI et un roboport personnel. Les corrections de retrait/reprise ont également des tests ciblés et des mutations en copies temporaires : réintroduire les défauts couverts doit faire échouer les tests correspondants.

Le scénario `singleton` vérifie le refus et le remboursement d’un dépôt supplémentaire, l’indépendance des forces et surfaces, puis la suspension et la récupération d’une ancienne flotte de quatre machines. Les anciennes fixtures `concurrency` restent une investigation historique ; elles ne sont plus compatibles avec la limite du produit et sont exclues de la suite courante.

Ce premier prototype ne constitue pas la qualification finale du mod : performances megabase, cohabitation avec les trains de production, toutes les géométries d’accessoires, paramètres copiés dans les blueprints, packs de conversion et graphismes définitifs restent à compléter. Les rails surélevés et rampes sont hors périmètre.

## Développement et installation locale

```sh
./build.sh lint            # syntaxe, métadonnées et tests ciblés
./build.sh test            # non-régressions, boucle et limite de flotte, sauvegardes réelles
python3 tests/engine.py --scenario singleton         # refus et anciennes flottes
./build.sh test --scenario module-east              # module horizontal : joueur natif, mission et sauvegarde
./build.sh test --scenario legacy-upgrade           # vraie sauvegarde de l'ancien runtime, mise à jour et rechargement
python3 tests/visual.py    # GUI, robots personnels, garde de retrait et capture hors écran
./build.sh package         # archive dans dist/
./build.sh devlink         # lien local dans ~/.factorio/mods
./build.sh unlink
```

Les tests utilisent des profils temporaires isolés et ne modifient pas la partie du joueur. Le test de sauvegarde ouvre un serveur temporaire privé lié uniquement à 127.0.0.1. Les tests graphiques utilisent le pilote SDL hors écran.

Les quatre scénarios `module-north`, `module-east`, `module-south` et `module-west` vérifient chacun la pose sur terrain vierge, la rotation native, les raccords des deux côtés, 52 poses en mouvement, deux ravitaillements, les deux accostages et la récupération. Une passe `--test-save` fournit les commandes natives du joueur sans écran ; une passe serveur distincte crée la vraie sauvegarde de mission, puis la recharge. Le rendu graphique ne peut pas être validé par ce mode serveur.

Le test `legacy-upgrade` crée une sauvegarde avec le code du commit `f14769e`, la charge avec le runtime courant puis recharge une sauvegarde de ce dernier. Le dépôt en pause, les trois véhicules, leurs identités et tous les contenus par objet et qualité doivent rester identiques. Il utilise l'historique Git local et des copies temporaires ; aucune sauvegarde du joueur n'est modifiée.

Dépendances locales des tests : Python 3, liblua5.4 et le moteur serveur officiel Factorio 2.1.24 avec les modules Quality et Recycler. Les tests et sondes utilisent `.tools/factorio-headless/bin/x64/factorio`, installation locale ignorée par Git, ou le chemin `FACTORIO_BIN`. Le moteur est disponible sur la [page officielle de téléchargement](https://factorio.com/download) : sélectionner la version serveur Linux 2.1.24 et extraire son dossier `factorio` sous `.tools/factorio-headless`.

Les tests graphiques exigent une version autonome avec graphismes, placée sous `.tools/factorio-standalone` ou désignée par `FACTORIO_GUI_BIN`, et un contexte OpenGL hors écran. En son absence, le test s'arrête avec un message explicite : aucun repli vers Steam. Le lanceur refuse aussi les moteurs Steam fournis par variable d'environnement et ne transmet pas les identifiants Steam au test graphique. Le statut Steam du joueur n'est pas modifié. `MODS_DIR` choisit le dossier de mods pour le lien de développement.

Les journaux courants sont dans tests/last-engine.log, tests/last-singleton.log et tests/last-visual.log. La [capture historique](docs/prototype-preview.png) représente l'ancien dépôt, avant le module traversant. Aucune capture du nouveau module n'a encore été validée avec un client graphique autonome. Les sondes indépendantes et leurs preuves restent sous tools/ et docs/ ; elles sont distinctes des tests du mod réel.

Le [LLD](docs/LLD.md) et la [spécification](specs/001-construction-train.md) décrivent la cible complète. Aucune publication n’est effectuée par le packaging.
