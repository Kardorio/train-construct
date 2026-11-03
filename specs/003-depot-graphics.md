# 003 — Graphismes du dépôt traversant

**Statut** : qualification moteur de la correction réussie le 3 novembre 2026 ; rendu corrigé à revoir par l’utilisateur en sandbox, après essai en jeu et captures de l'utilisateur. Geoffrey conserve la vue fidèle comme direction artistique, mais refuse le coffre au milieu de l'atelier et l'ancien voile gris avec liseré jaune. Le premier modèle 3D écarté reste hors du runtime.

## Problème

Le dépôt dispose de quatre vues industrielles, mais l'essai en jeu révèle un coffre disproportionné au milieu de l'atelier et la persistance de l'ancien voile gris avec liseré jaune. Le rendu doit retrouver le bâtiment complet sans perdre les contenus ni les échanges logistiques existants.

## Solution et périmètre

Un atelier latéral ouvert en acier sombre et jaune chantier, avec réserves de rails, établis, portique et stock intégré visuellement. Les quatre PNG runtime restent inchangés, avec leurs échelles et origines. Seul le couloir ferroviaire de ±1,5 case est découpé : chaque vue utilise deux bandes complètes, sans réservation centrale autour du stock. L'ancien `stock.png` est conservé hors du runtime dans `docs/concepts/stock-study.png`. Les images sources, consignes, repères et paramètres d'intégration restent dans le projet.

Le train conserve ses graphismes actuels pendant ce lot. Les véhicules définitifs, outils animés et effets de travail restent pour la suite. Aucun changement de navigation, recettes, stocks ou règles de chantier.

## Critères d'acceptation

- [ ] **AC1** Les quatre orientations conservent leurs équipements, leur lumière, leurs échelles et leurs origines ; le rendu corrigé est confirmé en jeu sans coffre au milieu de l'atelier ni ancien voile gris avec liseré jaune.
- [x] **AC2** Ouvrir le bâtiment donne accès au stock de 100 emplacements. Le conteneur technique est invisible au même emplacement, avec identité, contenus et échanges par bras conservés, y compris pour un module déjà présent.
- [x] **AC3** Les sprites affichés ne contiennent ni train ni voie peinte ; deux bandes complètes par vue laissent les raccords et un corridor de trois cases dégagés, sans découpe autour du stock.
- [x] **AC4** Les quatre PNG de bâtiment et la texture métallique sont inclus inchangés dans l'archive et les prototypes se chargent dans le moteur officiel. L'étude `stock-study.png` reste dans les concepts.
- [x] **AC5** Les missions, les stocks, la récupération et les sauvegardes restent compatibles avec les tests existants après correction. `Runtime.initialize` supprime l'ancien rendu sans recréation des entités.
- [x] **AC6** Les sources, le découpage et les limites de validation sont documentés. Une recomposition de contrôle des quatre vues est fournie ; elle n'est pas présentée comme une capture du jeu.
- [x] **AC7** Geoffrey approuve le rendu de la vue pilote fidèle avant les déclinaisons et demande son intégration au jeu.

## Phase unique — Atelier et stock

**Couvre** : AC1 à AC7.

**Impact sur les données** : le conteneur existant devient invisible sans déplacement ni recréation ; son inventaire, ses contenus et ses échanges logistiques sont conservés. `Runtime.initialize` retire l'ancien rendu. Aucune nouvelle entité de fonctionnement ni régénération de train.

**Définition de terminé** : images inchangées, deux bandes natives par vue, archive complète, lint et tests moteur réussis, revue sans défaut restant, puis confirmation du rendu corrigé en jeu. Aucun client Steam n'est lancé automatiquement.

**Qualification du 3 novembre 2026** : suite complète terminée avec un code de sortie 0, y compris les quatre orientations en mode natif, serveur et rechargement, les échanges du stock par bras, le nettoyage du décor via le vrai `Runtime.initialize`, les mutations et la migration legacy. Lint et `sprites-check` réussis ; aperçu inspecté dans le navigateur et archive produite. Le contrôle de l’aperçu sans cache est conservé. La qualification moteur est réussie ; AC1 reste ouvert jusqu’à la revue du rendu corrigé par l’utilisateur en sandbox.

## Correction de direction artistique

Le retour suivant précise l'alignement des extrémités : la bande métallique est raccourcie d'une case au début de la vue nord, de deux au sud et d'une pour les vues horizontales. Les images du bâtiment ne sont pas retouchées. Deux protections invisibles couvrent les côtés de l'atelier sans toucher au corridor ferroviaire. Elles refusent de nouvelles machines sur le bâtiment et sont créées à la mise à jour des anciens modules sans supprimer les objets du joueur. Le retrait enlève aussi ces protections. Les essais moteur couvrent le refus de pose, la conservation d'un fourneau préexistant et de son carburant, la migration idempotente, la rotation, les bras et la récupération.

Le second retour en jeu révèle une rupture du sol sous la voie et une zone de chargement trop courte. La texture métallique de Train Foundry est réutilisée sans retouche dans `graphics/entity/depot/platform.png`. Un `integration_patch` natif de 4 × 32 cases, sous les couches ferroviaires, relie les deux côtés dans les quatre orientations. Le ballast des seuls rails propres au dépôt est retiré ; les rails empruntés gardent leurs graphismes. Le terrain n'est pas remplacé et aucun objet décoratif supplémentaire n'est créé.

L'emprise du stock invisible s'étend sur 30,6 cases le long de l'atelier. Sa grille de placement reste de 3 × 3 pour conserver les positions enregistrées ; son orientation suit le module, y compris après mise à jour. Le bâtiment garde sa rotation native avant pose. Les essais moteurs vérifient deux apports par bras éloignés du centre vers le même inventaire ; les contrôles graphiques vérifient la couverture métallique sans trou ni superposition.

Le premier essai procédural était trop vide, trop propre et trop plat. Les rendus ont été arrêtés et archivés dans `.tools/art-output/rejected-renders` ; leur intégration a été retirée. Le conteneur et les sources expérimentales sont conservés pour le travail futur, sans imposer leur rendu comme graphisme final. La nouvelle intégration s'appuie directement sur les planches conservées pour retrouver la richesse visuelle du bâtiment.
