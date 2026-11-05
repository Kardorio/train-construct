# 007 — Déchargement des résidus de carburant

**Statut** : qualifié dans le moteur le 5 novembre 2026 ; essai utilisateur en partie restant à effectuer.

## Problème et solution

Les résidus des carburants Py saturent les locomotives. Au quai, le train transfère automatiquement les inventaires de résidus des deux locomotives vers le stock du dépôt. Des bras peuvent ensuite extraire ces objets comme les autres matériaux. Les objets gardent leur qualité. Le transfert ne dépend d'aucun nom d'objet Py.

Si le dépôt est plein, le surplus reste dans la locomotive, un message indique de libérer le stock et le départ attend la fin du déchargement. Le transfert reprend automatiquement dès qu'une place se libère. Il fonctionne aussi en pause au quai. Aucun transfert à distance ou pendant le mouvement.

## Critères d'acceptation

- [x] **AC1** Les deux locomotives déchargent leurs résidus au quai, avec quantités et qualités exactes, sans toucher à leur carburant ni à leur combustible en cours.
- [x] **AC2** Un dépôt plein ou partiellement disponible conserve exactement le surplus ; le départ attend avec un message explicite et reprend après libération de place.
- [x] **AC3** Une machine éloignée ou mobile ne transfère aucun résidu. Une machine en pause au quai peut décharger.
- [x] **AC4** Les résidus Py réellement produits par combustion sont déchargés ; le comportement sans résidu reste inchangé. Les bras et circuits utilisent le stock existant.

## Phase unique

**Couvre** : AC1 à AC4. **Données** : aucun nouvel inventaire ni changement du format des sauvegardes. **Terminé quand** : tests dans le moteur réel, conservation des objets, lint et non-régressions réussis ; paquet bêta régénéré. Geoffrey confirme la publication de la 0.1.0 et choisit une mise à jour 0.1.1.

## Vérifications

`./build.sh test-ashes` et sa variante `--profile fullPy` passent avec de vrais véhicules, inventaires et consommations Py. La fixture vérifie aussi deux qualités de résidus, un autre type de résidu, le transfert partiel, la pause, la reprise, la réutilisation d'une place libérée par le chargement, le déplacement et un vrai train sur voie parallèle. `--mutation` rejette une copie privée du worker où le déchargement a été désactivé.

La revue a révélé que l'ancien contrôle du quai acceptait une voie parallèle proche. L'écart latéral est désormais contrôlé par rapport au rail réellement connecté à l'arrêt ; le dépôt historique conserve son décalage latéral par rapport à la voie. Le test parallèle protège cette correction.
