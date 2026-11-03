# Direction artistique et production des graphismes

## Intention

Conserver l'identité du concept retenu : jaune chantier patiné, acier sombre, verre bleu gris, petits feux ambre et mécanismes de pose visibles. La nouvelle étude adapte cette identité au dépôt traversant validé en sandbox le 3 novembre 2026.

La planche initiale reste la référence approuvée. Geoffrey autorise la réalisation du bâtiment et du stock à partir de la nouvelle étude le 3 novembre 2026. La planche ne constitue pas elle-même une feuille de sprites.

## Dépôt

L'emprise actuelle est de 12 × 32 cases. Une voie droite traverse le module ; les deux raccords doivent rester visibles et accessibles. Le stock est situé à six cases sur le côté de la voie, au milieu du module. Le quai est décalé de dix cases le long de la voie et de deux cases latéralement.

Le bâtiment prend la forme d'un atelier latéral ouvert avec une dalle, un bloc de stockage identifiable, des réserves de rails et un petit portique de chargement. Les parties hautes restent sur le côté pour laisser voir les véhicules. La peinture jaune souligne les éléments utiles ; l'acier sombre forme la masse principale. Les rails et véhicules restent des entités séparées et ne doivent pas être peints dans le sprite du bâtiment vide.

Les quatre orientations nécessitent des vues cohérentes avec la caméra et la lumière du jeu. Faire tourner une image plate de 90° ferait également tourner sa lumière et sa perspective. Les façades, le stock et le quai doivent suivre le repère réel du module, sans réinterpréter leur place selon la vue.

## Machine

La silhouette comporte exactement trois véhicules : deux locomotives identiques opposées, avec leurs cabines aux extrémités extérieures, et un wagon central ouvert. Le wagon porte des faisceaux de rails et des compartiments de signaux ; un manipulateur compact replié complète son identité.

Les outils extérieurs sont courts et articulés. Ils matérialisent le contact au joint réel devant la machine. Leur dessin doit respecter les limites géométriques du runtime plutôt que suggérer une portée de construction supplémentaire.

## Découpage des assets

| Élément | Contenu | Contrainte de lecture |
| --- | --- | --- |
| Atelier | Quatre vues du bâtiment vide, avec sol et ombres séparables | Deux raccords dégagés et train visible |
| Stock | Intégré visuellement au bâtiment ; conteneur technique invisible au même emplacement | Ouverture du bâtiment : 100 emplacements ; échanges par bras conservés |
| Locomotive | Un modèle réutilisé pour les deux extrémités, orientations et ombres cohérentes | Cabine extérieure, outil compact, sens identifiable |
| Wagon | Un modèle avec charge ferroviaire et compartiments de signaux | Distinct d'un wagon de marchandises ordinaire |
| Outils | Repos, travail et retour au repos | Le contact visuel suit le contact autorisé |
| Icônes | Dépôt, locomotive et wagon | Reconnaissables en inventaire sans microdétails |

Les prototypes vanilla locaux de Factorio 2.1.24 utilisent 256 directions pour la locomotive et 128 pour le wagon de marchandises (`base/prototypes/entity/trains.lua`). Ce sont les références de continuité retenues pour préparer le rendu des véhicules ; les graphismes finaux devront être chargés et contrôlés dans le moteur.

## Ordre de réalisation

1. Examiner la nouvelle étude du dépôt occupé, du dépôt vide et de la machine dégagée.
2. Intégrer le stock visuellement au bâtiment, puis vérifier les quatre orientations avec les véhicules provisoires actuels.
3. Produire les locomotives et le wagon avec une caméra et une lumière communes, puis vérifier leur rotation sur les courbes.
4. Ajouter les outils mobiles et les effets discrets de travail une fois les silhouettes lisibles.
5. Contrôler au zoom habituel, pendant la pose en mouvement et lors du retour au dépôt.

Les sources de graphismes doivent rester réutilisables pour les orientations et les corrections. Une planche générée fournit une direction artistique ; elle ne garantit ni un alignement de sprites, ni une animation cohérente, ni une correspondance exacte avec les collisions.

Le client graphique autonome est absent de l'environnement de tests automatisés. L'utilisateur a néanmoins essayé le module en jeu et fourni des captures le 3 novembre 2026 : le coffre au milieu de l'atelier et l'ancien voile gris avec liseré jaune sont refusés. La qualification moteur de leur correction est réussie ; le rendu corrigé reste à revoir par l’utilisateur en sandbox. Aucun lancement Steam automatique n'est autorisé.

## Essai 3D écarté le 3 novembre 2026

Le modèle procédural conservé dans `tools/art/render_depot.py` a produit des vues cohérentes dans le moteur de rendu. Geoffrey les juge toutefois très éloignées du concept : atelier trop vide, trop propre et trop plat. La cohérence technique ne suffit pas à valider la direction artistique.

Les rendus ont été arrêtés et archivés dans `.tools/art-output/rejected-renders`. Leur intégration au runtime a été retirée. Cet essai n'est pas la base visuelle retenue pour les sprites intégrés ensuite.

La texture de métal peint produite avec imagegen reste dans `tools/art/painted-steel.png`, avec sa consigne. Le conteneur `construction-train-art:4.5.15` est conservé comme outil de travail. Python 3.11 et Blender n'ont pas été installés sur le poste. Python 3.11 correspond à la version requise par le [module officiel Blender 4.5](https://pypi.org/project/bpy/4.5.15/). Le rendu utilise quatre cœurs et 6 Go de mémoire au maximum, sans réseau, avec les sources en lecture seule et les fichiers de travail en écriture sous `.tools`.

Les commandes `./build.sh art-setup` et `./build.sh art-experiment` permettent de reconstruire l'outil et de reproduire cette expérience hors du mod. Elles ne constituent pas une livraison de graphismes validés.

## Reprise de la recherche visuelle

La reprise utilise directement les deux planches conservées pour reconstituer une vue du bâtiment vide, avec sa silhouette, ses portiques, sa densité mécanique et ses matières patinées. La consigne est conservée dans `depot-faithful-study.prompt.txt`. Une vue pilote doit retrouver cette qualité avant de produire de nouvelles orientations ou de modifier les prototypes du jeu.

Geoffrey approuve cette nouvelle base et confirme vouloir ce rendu dans le jeu. Les quatre vues du bâtiment et une étude de coffre symétrique ont été générées à partir de cette référence avec imagegen. Après l'essai en jeu, le coffre séparé est écarté du runtime et conservé dans `stock-study.png`. Les diagrammes de `tools/art/layout_guides.py` décrivent les places du couloir et du conteneur ; ce sont des contraintes de génération historiques, pas les graphismes finaux.

## Intégration des sprites 2D

Les quatre PNG du bâtiment sont dans `graphics/entity/depot` et restent inchangés. Un cinquième PNG, `platform.png`, reprend sans retouche la texture de sol métallique de Train Foundry. Ils ne contiennent ni train ni rails. Les véhicules continuent d'utiliser leurs graphismes vanilla. L'ancien `stock.png` est déplacé hors des graphismes runtime vers `docs/concepts/stock-study.png` pour conservation ; il n'est plus rendu en jeu. Les essais de retouche des contours n'ont pas été retenus.

`prototypes/depot-graphics.lua` affecte les vues à la direction native du module, sans rendu de coffre séparé. Les rectangles sources, leur échelle et leurs décalages sont calculés à partir des mesures explicites conservées dans `tools/art/prepare_sprites.py`. Les échelles et origines des quatre vues sont conservées. Les sprites du module sont centrés sur sa voie réelle, une case à droite et une case en bas de l'origine du bâtiment. Le conteneur technique invisible garde son emplacement effectif après alignement natif sur les demi-cases ; ouvrir le bâtiment donne accès à ses 100 emplacements.

Le découpage utilise les champs natifs de [Sprite](https://lua-api.factorio.com/latest/types/Sprite.html). Seul le couloir de ±1,5 case autour de la voie est exclu des images affichées pour dégager les vrais rails et le train. Chaque vue comporte exactement deux bandes complètes. La découpe autour du stock est supprimée : les poutres et les dalles recouvrent volontairement le conteneur invisible, le bâtiment représentant le stock intégré. Les détails des quatre vues peuvent varier légèrement ; il s'agit d'une première intégration de graphismes 2D, pas d'un modèle 3D commun.

La sélection et les rails gardent leurs dimensions et leur fonctionnement. Au chargement, `Runtime.initialize` supprime l'ancien rendu responsable du voile gris et du liseré jaune. Aucun inventaire, véhicule ou composant n'est recréé ; les identités, contenus et échanges avec les bras sont conservés. Le changement des prototypes impose un redémarrage complet de Factorio. La correction est qualifiée dans le moteur ; sa validation visuelle en sandbox reste attendue.

Le retour suivant en jeu relève une bande de terrain rompant la continuité sous les rails et une zone de chargement limitée au centre. Le module porte désormais un `integration_patch` métallique de 4 × 32 cases, sous les couches des rails. Il raccorde les deux parties de la dalle sans modifier les tuiles de terrain. Les rails propres au dépôt perdent leur ballast ; les rails du joueur réutilisés restent inchangés. La texture vient de `Train-Foundry/graphics/foundry-platform-tile-v1.png` et n'est pas rééchantillonnée.

Le conteneur invisible conserve son centre et ses contenus ; son emprise s'allonge à 30,6 cases dans la direction du bâtiment. Sa grille de placement reste de 3 × 3 et son orientation est remise à jour au chargement. Les tests placent deux vrais bras à distance du centre, vérifient leur absence de collision et attendent leurs transferts vers l'inventaire commun. Le sol est recomposé dans l'aperçu ; le contrat vérifie ses 128 cases sans trou ni recouvrement.

Les captures suivantes précisent la découpe : retrait d'une case au début du sol nord et des vues horizontales, de deux pour le sud, sans toucher à l'autre extrémité ni aux PNG. Les protections latérales invisibles empêchent aussi de construire sur l'atelier et la passerelle. Elles couvrent toute la longueur du bâtiment, laissent le rail libre et se retirent avec le module. Une sauvegarde existante reçoit ces protections sans suppression des machines que le joueur aurait déjà posées sur le bâtiment ; celles-ci doivent être retirées manuellement. L'aperçu et le contrôle de couverture utilisent les nouvelles dimensions, de 124 cases au nord et dans les vues horizontales, 120 au sud.

```sh
python3 tools/art/prepare_sprites.py  # régénérer uniquement les métadonnées Lua
./build.sh sprites-check             # PNG, géométrie des rectangles et archive
./build.sh sprites-preview           # recomposition hors jeu pour inspection
./build.sh test                      # chargements et missions réels avec les sprites
```

L'[aperçu de contrôle](../depot-sprite-preview.html) utilise les mêmes rectangles, échelles et décalages que les prototypes, avec deux bandes par vue, sans coffre ni réservation rose. Son contrat indique `stock=false` et `integrated=true`. Ses rails sont schématiques ; il ne remplace pas une capture du jeu et ne valide pas l'éclairage ou l'ordre de rendu du client Factorio. Le contrôle graphique automatisé reste indisponible faute de client autonome ; après les captures ayant motivé la correction, une nouvelle recette visuelle dans la sandbox du joueur reste nécessaire. La suite complète s’est terminée avec un code de sortie 0, incluant les quatre orientations en mode natif, serveur et rechargement, les échanges par bras, le nettoyage du décor via `Runtime.initialize`, les mutations et la migration legacy. Lint et `sprites-check` sont réussis, l’aperçu a été inspecté dans le navigateur et l’archive a été produite. Ces résultats qualifient le fonctionnement moteur, sans valider le rendu corrigé en jeu.
