# Fiche et visuels du portail

Ce dossier prépare la fiche du portail, sur le modèle de Vehicle Loading Dock. Aucune publication n'est effectuée.

- [description.en.md](description.en.md) : présentation à copier dans la description longue du portail.
- [description.fr.md](description.fr.md) : version française correspondante pour relecture.
- [metadata.json](metadata.json) : identité publique, propositions de résumés, vignette et galerie.

La bêta conserve sa description demandée **`Beta, do not download`**. Les présentations complètes ci-dessus sont des brouillons pour une future mise à jour de la fiche ; leur création ne change ni le portail ni les métadonnées du paquet bêta.

Les images des descriptions utilisent des liens absolus vers `https://raw.githubusercontent.com/Kardorio/train-construct/master/portal/`. Les fichiers doivent être poussés sur la branche publique `master` avant de coller la fiche sur le portail ; la présence locale des médias ne les rend pas accessibles à ces adresses. Les deux descriptions ouvrent sur le GIF réel de construction et montrent l'atelier final. L'illustration de couverture reste disponible dans la galerie, distincte des captures de jeu.

## Médias conservés

- [Démonstration animée](gallery/construction-block-captioned-v3.gif) : vraie capture aérienne fixe de Factorio, avec l'atelier final, le plan en fantômes, la construction des rails et signaux puis le retour au dépôt.
- [Vidéo avec titres](gallery/construction-block-captioned-v3.mp4) et [version sans titres](gallery/construction-block-v2.mp4) pour les montages.
- Captures [du plan](gallery/construction-block-captioned-v3-blueprint.png) et [du chantier terminé](gallery/construction-block-captioned-v3-idle.png).
- [Illustration de couverture](construction-train-cover-v1.png) : image promotionnelle générée montrant le train en train de poser un rail ; ce n'est pas une capture du jeu.
- [Vignette](../thumbnail.png), [icône du dépôt](../graphics/icons/construction-depot-v1.png) et [icône de technologie](../graphics/technology/railway-construction-v1.png), également distribuées avec le mod.

Les titres du GIF sont ajoutés au centre de la boucle et synchronisés avec les phases réellement enregistrées : plan prêt, rails, signaux, retour et attente. Cette démonstration ne contient pas d'arrêt de train. Le fichier de sous-titres ASS et les métadonnées JSON accompagnent les médias. La lecture est accélérée six fois, avec une pause au début et à la fin.

La capture utilise le vrai runtime et les mouvements natifs du train. Les entités construites et le retour au quai ont été vérifiés pendant l'enregistrement ; les images proviennent de `game.take_screenshot`, puis sont assemblées avec FFmpeg. Aucune sauvegarde du joueur n'est modifiée et aucun client Steam n'est lancé.

Les concepts, images sources et outils de génération restent conservés localement, hors Git. Le dépôt contient ici les documents et médias finaux destinés à la publication.
