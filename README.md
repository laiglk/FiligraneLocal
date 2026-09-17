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

### Installation rapide avec le DMG

1. Ouvre la page [Releases](https://github.com/laiglk/FiligraneLocal/releases/latest).
2. Télécharge le fichier `FiligraneLocal-v1.1.0.dmg`.
3. Ouvre le DMG puis glisse **Filigrane Local** dans le raccourci **Applications**.
4. Lance l’application depuis le dossier Applications.

> L’application n’est pas notarée par Apple. Si macOS la bloque au premier lancement, fais un clic droit sur l’application, choisis **Ouvrir**, puis confirme.

### Compiler soi-même

Prérequis : macOS 13 ou version ultérieure et les outils de développement Apple gratuits.

```bash
xcode-select --install
bash build.command
```

L’application est créée dans `build/FiligraneLocal.app`.

> L’application est compilée et signée localement sur ton Mac. Elle n’est pas distribuée avec une signature Developer ID.

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
