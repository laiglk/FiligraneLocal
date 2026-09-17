# Filigrane Local

Application macOS gratuite et open source pour ajouter un filigrane à des **PDF et images**, entièrement en local.

Elle a été conçue pour préparer des copies de documents sensibles destinées à un tiers (agence d’intérim, bailleur, organisme administratif, etc.) sans envoyer ces documents vers un service en ligne.

## Confidentialité

- aucun document n’est envoyé sur Internet ;
- aucun compte ni serveur n’est utilisé ;
- les originaux ne sont jamais modifiés ;
- les métadonnées EXIF/GPS des images ne sont pas recopiées ;
- les PDF sont recréés avec le filigrane intégré au contenu.

Le code source est court et consultable dans [`main.swift`](main.swift).

## Fonctionnalités

- PDF, JPG/JPEG, PNG, WebP, HEIC/HEIF et TIFF ;
- ajout de plusieurs fichiers par sélection ou glisser-déposer ;
- texte, opacité et angle personnalisables ;
- filigrane unique ou répété sur toute la page ;
- choix du dossier de sortie ;
- noms de sortie automatiques en `*_filigrane.ext` ;
- fonctionnement 100 % local.

## Installation

### Prérequis

- macOS 13 ou version ultérieure ;
- les outils de développement Apple gratuits.

Installe les outils Apple une seule fois si nécessaire :

```bash
xcode-select --install
```

### Compiler l’application

1. Télécharge le dépôt avec **Code → Download ZIP**, puis décompresse-le.
2. Ouvre Terminal dans le dossier du projet.
3. Lance :

```bash
bash build.command
```

L’application est créée dans :

```text
build/FiligraneLocal.app
```

Tu peux ensuite la déplacer dans le dossier `Applications`.

> L’application est compilée et signée localement sur ton Mac. Elle n’est pas distribuée avec une signature Developer ID ni notarée par Apple.

## Utilisation

1. Ajoute ou glisse tes documents dans la fenêtre.
2. Saisis un texte précis, par exemple :
   `DESTINÉ UNIQUEMENT À [AGENCE] — DOSSIER INTÉRIM — 17/09/2026`
3. Règle l’opacité, l’angle et la répétition.
4. Choisis le dossier de sortie.
5. Clique sur **Créer les copies filigranées**.

Teste d’abord le rendu sur un document non sensible et vérifie chaque copie avant de l’envoyer.

## Limites connues

- La recréation d’un PDF peut supprimer ses liens, formulaires et autres éléments interactifs.
- Un filigrane réduit les possibilités de réutilisation frauduleuse, sans constituer une protection absolue.
- Ne joins jamais de véritable document d’identité ou document confidentiel à une issue GitHub.

## Développement

L’application utilise uniquement les frameworks Apple : AppKit, PDFKit, CoreText, ImageIO et UniformTypeIdentifiers. Aucune dépendance externe n’est téléchargée.

La compilation est vérifiée automatiquement sur macOS par GitHub Actions.

## Licence

Distribué sous licence [MIT](LICENSE).
