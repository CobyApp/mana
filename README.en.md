<div align="center">

# NOIZ

**A papery, noise-soaked comic reader.**

ZIP, RAR and PDF comic viewer for iPad / iPhone.
Manga / glitch styling makes "reading" feel intentional.

[日本語](README.md) · [한국어](README.ko.md) · [English](README.en.md)

[Website](https://cobyapp.github.io/mana/) · [Privacy Policy](https://cobyapp.github.io/mana/privacy/) · [Support](https://cobyapp.github.io/mana/support/)

</div>

---

## ✦ Features

- A unified library that opens **ZIP / RAR / PDF** as-is.
- **Single / dual page** layouts, **left→right / right→left** progression, **first-page solo** for spreads.
- Folders, multi-select bulk move/delete, drag & drop.
- Files live under Application Support and the catalog is reconciled on launch, so a reinstall does not lose your library.
- Haptics on; no in-app sound. Reading stays quiet.
- Manga / glitch design tokens — halftone backgrounds, heavy ink borders, speed lines.

## ✦ Requirements

- iOS / iPadOS **17.0 +**
- iPhone / iPad (iPad Pro recommended)

## ✦ Languages

In-app UI is available in **Japanese / Korean / English**. Picking "System" under Settings → App Language follows the device locale automatically.

## ✦ Development

SwiftUI + The Composable Architecture, modularised via Tuist.

```bash
bash Scripts/setup.sh
open Mana.xcworkspace
```

See [`docs/DEPLOY.md`](docs/DEPLOY.md) for TestFlight auto-deploy.

## ✦ License

Personal project. Bundled libraries follow their own licenses.
