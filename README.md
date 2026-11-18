# Construction Train

Le dépôt dispose de filtres par catégorie et d'une lecture de son stock sur les réseaux logiques rouge et vert.

Mod local pour **Factorio 2.1.24 ou ultérieur**. Une seule machine de chantier **locomotive — wagon central — locomotive** est autorisée par planète. Son bâtiment orientable génère sa propre voie traversante, son stock, son quai et son train. Le joueur raccorde les deux extrémités au réseau. Le train construit les rails planifiés au contact et pose au passage les accessoires compatibles avec son retour et sa reprise de chantier.

Le module traversant dispose de quatre vues industrielles propres au mod, dérivées de la référence visuelle. Un sol métallique continu passe sous les rails et relie les deux côtés de l'atelier. Le bâtiment représente visuellement le stock intégré. Les véhicules disposent de sprites spécifiques : locomotives jaunes avec cabines extérieures et pinces courtes, wagon ouvert avec rails, signaux et manipulateur replié. Chaque véhicule utilise 64 orientations, obtenues par reprojection des 16 vues de référence conservées. Ce sont des vues intermédiaires en 2D, pas de nouveaux rendus 3D ; les changements de perspective entre références restent à apprécier en jeu. Une pince du nez actif s'anime après chaque pose de rail réussie, sans modifier la conduite ni les matériaux consommés. Le dessin reprend un atelier industriel jaune et patiné.

Les côtés de l'atelier empêchent de poser d'autres machines sur le bâtiment. La voie centrale et les bras de chargement extérieurs restent utilisables. Les machines déjà présentes sur l'atelier avant cette correction sont conservées ; les retirer manuellement.

## Essayer le prototype

1. Activer **Construction Train** dans le menu des mods et redémarrer Factorio.
2. Rechercher **Construction ferroviaire spécialisée**, après la recherche ferroviaire automatisée.
3. Choisir un terrain libre sur terre. Tenir le dépôt en main et utiliser **R avant la pose** pour orienter sa voie nord-sud ou est-ouest ; les quatre directions cardinales sont possibles.
4. Poser le module sans préparer de voie. Il génère quinze rails, deux locomotives, le wagon central, le quai et son stock intégré au bâtiment. L'objet inclut le coût des quinze rails internes. Un placement invalide est refusé et remboursé dans sa qualité. Une seconde pose sur la même planète est refusée.
5. Avec des rails vanilla, prolonger les **deux extrémités sélectionnables** et raccorder le module au réseau dans les deux sens. Aucun raccord extérieur n'est créé automatiquement. La rotation du bâtiment est verrouillée après sa pose.
6. Ouvrir le bâtiment, **y déposer les matériaux et le carburant** dans son stock de 100 emplacements, puis cocher les catégories à construire et régler les objectifs de chargement. Valeurs initiales : **400 rails, 50 signaux, 50 signaux chaînés, 10 arrêts et une réserve de carburant équivalant à 100 charbons (50 par locomotive)**. Une catégorie décochée ne conditionne pas le départ.
7. Poser un blueprint ferroviaire raccordé à des rails réels accessibles. Le train cherche son chantier et démarre lorsque son chargement est prêt.

Cliquer sur le bâtiment ouvre l'inventaire natif de 100 emplacements et le panneau du train. Des bras peuvent alimenter ce même stock le long du côté extérieur de l'atelier, jusque vers les deux extrémités. Le wagon central possède son propre stock de 100 emplacements. Le chargement automatique accepte les carburants compatibles avec les locomotives, y compris ceux des mods et leurs qualités. La réserve est comptée en énergie, en incluant le combustible déjà en cours de consommation ; un carburant plus puissant demande moins d’objets. Le panneau indique les matériaux ou la réserve d’énergie manquants au départ.

Au quai, les résidus de carburant des deux locomotives sont automatiquement transférés dans le stock du dépôt, même lorsque la machine est en pause. Cela comprend les cendres Py et les résidus d'autres carburants, avec leur qualité. Des bras peuvent les extraire du bâtiment ; ils apparaissent aussi dans la lecture du stock par circuit. Si le dépôt manque de place, le surplus reste dans les locomotives et le départ attend avec un message demandant de libérer le stock. Le déchargement et le départ reprennent automatiquement après libération de place. Aucun résidu n'est transféré pendant le mouvement ou loin du quai.

Les anciens dépôts restent fonctionnels dans leur disposition d'origine : aucun train n'est recréé et aucune voie ne leur est ajoutée automatiquement. Les nouveaux objets posent le module traversant. Ce changement de prototypes exige un **redémarrage complet de Factorio**.

Le panneau permet de démarrer, mettre en pause, rappeler la machine ou récupérer l’ensemble. Les locomotives spécialisées disposent d’une puissance et d’un freinage quadruplés, avec la même vitesse maximale ; leur consommation augmente. Les trajets utilisent le moteur et la signalisation de Factorio : aucune navigation sur les ghosts ni génération de tracé.

## Fabrication et recherche avec Pyanodon

Avec Py Coal Processing ou Py Industry, la recherche du dépôt reprend les packs scientifiques, leur quantité et la durée de la recherche ferroviaire automatisée après les ajustements de Py. Celle-ci reste son prérequis.

La recette Py utilise 2 locomotives, 1 wagon de marchandises, 4 coffres en acier, 40 plaques d'acier, 40 petites pièces mécaniques avec Py Petroleum Handling, 15 circuits imprimés et 15 rails. Sans Petroleum Handling, les 40 engrenages sont conservés. Les circuits imprimés Py High Tech utilisent l'identifiant `electronic-circuit`, qui désigne les circuits verts dans le jeu de base. Sans Py, la recette conserve ses 30 circuits verts et ses 40 engrenages, et la recherche vanilla reste inchangée.

## Pose au passage et ravitaillement

Quatre cases indépendantes choisissent ce que le train construit : rails, signaux ordinaires, signaux chaînés et arrêts. Pour un bloc sans signaux chaînés, cocher seulement rails et signaux ordinaires. Décocher une catégorie conserve sa quantité cible et les objets déjà embarqués, mais arrête son chargement et sa construction. Les ghosts exclus restent disponibles pour les robots, même si la réservation planétaire est activée. Une quantité cible nulle autorise toujours la construction avec les objets déjà embarqués ; elle ne remplace pas le filtre.

Les accessoires peuvent être sélectionnés seuls : le train recherche leurs ghosts sur les voies réelles reliées au dépôt, sans poser de nouveaux rails. Les règles de circulation et de retour restent prioritaires. Si toutes les catégories sont décochées, aucun chantier n'est accepté. Un changement pendant une mission provoque un arrêt natif puis une nouvelle recherche de travail autorisé.

## Copier les réglages du dépôt

Un blueprint du dépôt conserve les quatre catégories de construction, leurs quantités cibles, la réserve de carburant, la réservation des robots et les options de lecture du stock. Le copier-coller natif de réglages applique les mêmes paramètres ; les autres tags du blueprint restent préservés.

Le dépôt reconstruit avec ces réglages commence **en pause** : cliquer sur **Démarrer** quand ses stocks sont prêts. Les tags ne contiennent ni inventaires, ni identités, ni missions du train ; un module cloné reçoit un stock intégré neuf et vide. La limite d'une machine par planète reste applicable. La conservation concerne les blueprints, la copie des réglages et les clones du module ; un objet ordinaire miné puis reposé ne porte pas ces tags.

## Lecture du stock par réseau logique

Relier directement le bâtiment avec un fil rouge ou vert à un poteau ou un circuit. Le connecteur se trouve côté atelier et suit les quatre orientations. La lecture native du contenu est activée lors de la première mise à jour du dépôt ; son réglage reste ensuite mémorisé. Chaque réseau reçoit les quantités réelles et leurs qualités présentes dans le stock du dépôt. Les contenus du wagon et des locomotives sont exclus. Ce raccordement sert uniquement à lire le stock : les signaux reçus ne démarrent, ne mettent en pause et ne rappellent pas le train.

## Construction et retour au dépôt

Les matériaux viennent du wagon central. Une rupture de stock pendant la pose des rails provoque un retour au quai, un rechargement et la reprise du chantier. Le dépôt accepte les deux sens d’accostage. Si un retour direct est impossible, le train cherche un dégagement sur les rails déjà desservis pour inverser sa marche ; quatre manœuvres au maximum sont tentées, puis un blocage explicite attend une correction du réseau.

Le train prolonge sa destination dès que l’outil atteint le prochain rail, sans imposer un arrêt à chaque pose. La vitesse est limitée à proximité du front de construction ; les trajets sur le réseau existant conservent leur vitesse normale. Des arrêts restent possibles aux embranchements, aux signaux et pendant les manœuvres.

Avant de partir vers un rail fantôme et pendant son approche, le train vérifie que le rail peut réellement être posé. Un arbre, rocher ou bâtiment présent reste bloquant même s'il est marqué à déconstruire. Le panneau indique l'attente de dégagement ; le chantier est réexaminé automatiquement après le nettoyage par les robots ou le joueur. Un obstacle apparu pendant l'approche déclenche l'arrêt du train contrôlé. Les autres frontières constructibles restent candidates.

Le train ne mine ni ne détruit ces obstacles. Ce contrôle concerne les approches de construction ; il ne remplace pas la signalisation et les règles de circulation sur le réseau existant. Le déblaiement par le train est reporté à un lot ultérieur.

Signaux, chain signals et arrêts sont construits uniquement sur les rails desservis, avec vérification du contact et du rattachement. Les accessoires au contact peuvent être posés pendant le déplacement. Pendant la construction des rails, un signal sans signal opposé déjà réel est différé : il pourrait rendre tout le tronçon à sens unique. Les signaux qui compromettraient le retour ou la reprise depuis le dépôt sont également différés. Les accessoires restants font ensuite l’objet de trajets dédiés ; un sens unique impossible ou une branche trop courte peut laisser des travaux en attente.

Au ravitaillement des rails, l’absence d’accessoires complémentaires ne bloque pas le départ. Au ravitaillement des accessoires, le matériau effectivement manquant reste obligatoire. Le premier départ attend les objectifs configurés.

Un ghost ferroviaire isolé n’est pas un chantier accessible. Les arbres, rochers, falaises, eau et autres obstacles doivent être traités séparément.

## Réserver les rails aux trains

Le réglage du bâtiment réserve uniquement les **catégories cochées parmi les rails au sol, signaux, signaux chaînés et arrêts pris en charge, sur toute la même planète/surface pour la même force**. Il est activé par défaut après la pose réelle du bâtiment et peut être désactivé.

Dans une ancienne sauvegarde avec plusieurs bâtiments, l’exclusion reste active tant qu’au moins l’un d’eux la demande. Le panneau indique ce nombre. À la dernière désactivation ou au retrait du dernier bâtiment demandeur, les ghosts sont restitués progressivement aux robots. Un robot déjà en route est autorisé à finir sa pose.

Le prototype conserve de vrais ghosts dans une force technique amie de leur propriétaire. La copie native de blueprint, les robots de réseau et les robots personnels ont été exercés. L’édition complète des plans, les fils, les upgrades et les interactions avec d’autres mods restent à qualifier.

**Avant de désinstaller le mod**, désactiver l’option dans tous ses bâtiments ou récupérer ces bâtiments, puis laisser le jeu terminer la restitution. L’indexation et la restitution sont progressives ; leur durée augmente avec la carte. Ne pas retirer le mod alors que des ghosts appartiennent encore à sa force technique.

## Récupération et sécurité

Le bouton de récupération retire aussi les véhicules éloignés, après vérification de tous les composants. Les matériaux et carburants stockés sont déposés près des véhicules ; ils ne sont pas téléportés jusqu’au bâtiment. Un joueur à bord ou un véhicule encore mobile diffère l’opération.

Les rails internes ne sont pas minables séparément. La récupération retire ceux créés par le module et préserve les rails du joueur, y compris des rails déjà présents réutilisés à la pose. Un train tiers sur la voie interne diffère le retrait ; le coffre et le train de chantier ne sont pas supprimés sous le trafic.

Le minage natif et la récupération par script ne remboursent pas deux fois le bâtiment et conservent sa qualité. Une machine endommagée ne génère pas de remplaçante gratuite. Une modification du planning par le joueur ou une prise de contrôle suspend l’automatisation, y compris juste avant une pose.

Une ancienne sauvegarde contenant plusieurs dépôts sur une planète suspend ces machines et conserve leurs contenus. Récupérer les bâtiments supplémentaires, puis cliquer sur **Démarrer** pour la machine restante. Le rappel est également bloqué pendant ce conflit ; les bâtiments ne sont jamais supprimés automatiquement.

## Construire et installer

Le dépôt Git contient les sources du mod, ses graphismes et les scripts de fabrication. Python 3 est nécessaire pour créer les archives ; aucune dépendance Python supplémentaire n'est requise pour le build.

```sh
./build.sh package beta  # dist/train-construct_0.1.1.zip, pour le portail
./build.sh devlink-beta  # installer les sources sous l'identifiant public train-construct
./build.sh package       # archive de la variante locale construction-train
./build.sh devlink       # lien de la variante locale dans ~/.factorio/mods
./build.sh unlink        # retirer le lien de la variante locale
```

Le paquet bêta porte l'identifiant **train-construct**, le titre **Construction Train (Beta)** et la description **Beta, do not download**. La variante locale porte l'identifiant **construction-train**. Les deux variantes sont destinées à des installations distinctes ; ne pas les activer ensemble. Elles ne transfèrent pas automatiquement les données de sauvegarde de l'une à l'autre.

`devlink-beta` conserve les ZIP publics homonymes en sauvegarde locale et installe les sources sans modifier la liste des mods actifs. `MODS_DIR` permet de choisir le dossier des mods. Redémarrer complètement Factorio pour recharger les prototypes et les sprites.

La fabrication du ZIP et l'installation locale ne publient rien sur le portail.

La [fiche du portail](portal/README.md), ses présentations française et anglaise ainsi que les médias finaux sont conservés dans `portal/`.

## Tests

Les tests automatisés et leurs outils nécessaires font partie du dépôt. Les concepts, rendus expérimentaux et médias de travail restent locaux.

```sh
./build.sh lint          # syntaxe, métadonnées et tests unitaires
./build.sh test          # scénarios moteur, sauvegardes et non-régressions
./build.sh test-py       # recettes et recherche avec les archives Py installées
./build.sh test-ashes    # déchargement des résidus
./build.sh sprites-check # dimensions, calage et présence des sprites dans les archives
```

Les tests nécessitent Python 3, Pillow, liblua5.4 et le moteur officiel headless Factorio 2.1.24, installé dans `.tools/factorio-headless` ou désigné par `FACTORIO_BIN`. Les tests graphiques avec joueur exigent un client autonome dans `.tools/factorio-standalone` ou désigné par `FACTORIO_GUI_BIN`. Aucun test ne doit lancer le client Steam. Les journaux et rapports générés restent ignorés par Git.
