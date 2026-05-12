<div align="center">

# NOIZ

**ノイズの効いた、紙のような漫画リーダー。**

iPad / iPhone のための ZIP・RAR・PDF コミックビューア。
マンガ／グリッチ調のデザインで「読む」を演出します。

[日本語](README.md) · [한국어](README.ko.md) · [English](README.en.md)

[公式サイト](https://cobyapp.github.io/mana/) · [プライバシーポリシー](https://cobyapp.github.io/mana/privacy/) · [サポート](https://cobyapp.github.io/mana/support/)

</div>

---

## ✦ 特長

- **ZIP / RAR / PDF** をそのまま開ける統一ライブラリ。
- **シングル / デュアルページ** 表示、**左→右 / 右→左** の進行方向、**表紙単独表示** に対応。
- フォルダで整理、複数選択して一括移動／削除、ドラッグ＆ドロップ。
- 端末再インストールでも作品が消えないよう、ライブラリは Application Support に保存しつつ起動時に自動再同期。
- ハプティクス（バイブ）あり、音は鳴らさない。読書中の静けさを尊重。
- マンガ／グリッチ調の UI トークン（ハーフトーン背景、太字インクボーダー、スピードライン）。

## ✦ システム要件

- iOS / iPadOS **17.0 以上**
- iPhone / iPad（iPad Pro 推奨）

## ✦ 言語

アプリ内 UI は **日本語 / 한국어 / English** に対応。設定 → アプリ言語で「システムに従う」を選ぶと、デバイスの言語を自動追従します。

## ✦ 開発

Tuist でモジュール分割した SwiftUI + The Composable Architecture プロジェクトです。

```bash
bash Scripts/setup.sh
open Mana.xcworkspace
```

詳細は [`docs/DEPLOY.md`](docs/DEPLOY.md)（TestFlight 自動配信）を参照。

## ✦ ライセンス

このリポジトリは個人プロジェクトです。アプリ内で使用しているライブラリのライセンスは各プロジェクトに従います。
