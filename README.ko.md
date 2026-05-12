<div align="center">

# NOIZ

**노이즈를 입은, 종이 같은 만화 리더.**

iPad / iPhone 용 ZIP·RAR·PDF 코믹 뷰어.
만화 / 글리치 톤 디자인으로 "읽기"를 연출합니다.

[日本語](README.md) · [한국어](README.ko.md) · [English](README.en.md)

[공식 사이트](https://cobyapp.github.io/mana/) · [개인정보처리방침](https://cobyapp.github.io/mana/privacy/) · [지원](https://cobyapp.github.io/mana/support/)

</div>

---

## ✦ 특징

- **ZIP / RAR / PDF** 를 그대로 여는 통합 라이브러리.
- **한 페이지 / 두 페이지** 모드, **왼쪽→오른쪽 / 오른쪽→왼쪽** 진행 방향, **첫 페이지 단독** 표시 지원.
- 폴더로 정리, 다중 선택 후 일괄 이동/삭제, 드래그 앤 드롭.
- 재설치해도 작품이 사라지지 않도록 라이브러리를 Application Support 에 저장하고 시작 시 자동 재동기화.
- 햅틱(진동)은 살리고 소리는 안 냄. 독서 중의 고요함을 존중.
- 만화 / 글리치 톤의 UI 토큰(하프톤 배경, 두꺼운 잉크 보더, 스피드라인).

## ✦ 시스템 요구사항

- iOS / iPadOS **17.0 이상**
- iPhone / iPad (iPad Pro 권장)

## ✦ 언어

앱 내 UI 는 **한국어 / 日本語 / English** 지원. 설정 → 앱 언어에서 "시스템"을 선택하면 기기 언어를 자동 추종합니다.

## ✦ 개발

Tuist 로 모듈을 분리한 SwiftUI + The Composable Architecture 프로젝트입니다.

```bash
bash Scripts/setup.sh
open Mana.xcworkspace
```

자세한 내용은 [`docs/DEPLOY.md`](docs/DEPLOY.md) (TestFlight 자동 배포) 참조.

## ✦ 라이선스

개인 프로젝트입니다. 앱이 사용 중인 라이브러리들의 라이선스는 각 프로젝트를 따릅니다.
