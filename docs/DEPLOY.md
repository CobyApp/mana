# TestFlight 자동 배포 가이드

main 브랜치에 `v*` 형식의 태그를 푸시하면 [.github/workflows/deploy.yml](../.github/workflows/deploy.yml) 이 macOS 러너에서 archive → IPA export → TestFlight 업로드까지 자동으로 실행한다. 수동 실행은 Actions 탭의 **Run workflow** 버튼.

서명은 Xcode automatic signing + App Store Connect API key 인증으로 처리되므로, Provisioning Profile을 따로 만들고 시크릿에 넣어둘 필요가 없다. Distribution 인증서(.p12) 와 API key 만 있으면 된다.

## 필요한 GitHub Secrets

`Settings → Secrets and variables → Actions → New repository secret`

| 이름 | 내용 |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | Apple Distribution `.p12` 인증서를 `base64 -i cert.p12 \| pbcopy` 한 값 |
| `P12_PASSWORD` | 위 `.p12` 내보낼 때 지정한 비밀번호 |
| `KEYCHAIN_PASSWORD` | 러너에서 임시 keychain 만들 때 쓸 임의의 비밀번호 (아무거나) |
| `APPSTORE_KEY_ID` | App Store Connect API Key ID (예: `THVKAXN6PZ`) |
| `APPSTORE_ISSUER_ID` | App Store Connect Issuer ID (UUID 형식) |
| `APPSTORE_PRIVATE_KEY` | `.p8` API 키 파일 **내용 전체** (`-----BEGIN PRIVATE KEY-----` 부터 끝까지). base64 인코딩하지 말고 그대로 |

## 한 번만 준비해야 하는 것들

### 1. App Store Connect API Key
1. https://appstoreconnect.apple.com/access/integrations/api 접속
2. **Team Keys** 탭에서 `+` 버튼 → Name 지정 (예: "Mana CI/CD"), Access: **App Manager** 이상
3. 발급 후 `.p8` 파일 다운로드 (한 번만 받을 수 있음)
4. **Issuer ID** (페이지 상단)와 **Key ID** (생성된 키의 ID) 기록

### 2. Distribution 인증서
1. Xcode → Settings → Accounts → 팀 선택 → **Manage Certificates...**
2. `+` → **Apple Distribution** 생성 (또는 이미 있으면 그걸 사용)
3. Keychain Access에서 `Apple Distribution: ...` 인증서를 우클릭 → **Export** → `.p12` 로 저장 (이때 비밀번호 지정)
4. `base64 -i cert.p12 | pbcopy` 로 base64 복사

### 3. App Store Connect 에 앱 등록
TestFlight 업로드는 사전에 앱 레코드가 있어야 한다. 처음 한 번 https://appstoreconnect.apple.com/apps 에서 `+ → 신규 앱` 으로 등록:
- 플랫폼: iOS
- 이름: NOIZ
- 기본 언어: 한국어
- 번들 ID: `com.coby.mana`
- SKU: 임의 식별자 (변경 불가). 예: `noiz`

## 사용법

```bash
git tag v1.0.1
git push origin v1.0.1
```

또는 GitHub UI의 **Actions → Deploy to TestFlight → Run workflow** 에서 수동 트리거.

빌드 번호는 GitHub Actions의 run number 가 자동으로 들어간다. 필요하면 `workflow_dispatch` 입력 `build_number` 로 오버라이드.

## 트러블슈팅

- **인증서 import 실패**: `.p12` 파일에 Apple Distribution 인증서 + private key 둘 다 들어있는지 확인 (Keychain Access에서 export 시 인증서 + 키 모두 선택)
- **automatic signing 실패**: API Key의 Access 권한이 **App Manager** 이상인지, App Store Connect 에 동일 Bundle ID 의 앱이 등록돼있는지 확인
- **upload 권한 오류**: API Key 권한 확인
