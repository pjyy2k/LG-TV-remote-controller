# App Store 제출 준비

코드와 빌드 쪽 준비는 끝났습니다. 아래는 App Store Connect에서 직접 입력해야 하는 항목입니다.

## 앱 이름과 상표

- 앱 이름(App Store): `TV 리모컨 - LG webOS TV용`
  - "LG"로 시작하는 이름은 LG전자 허가 없이 쓰면 거절될 수 있어, 호환 대상을 설명하는 형태로만 씁니다.
- 기기 홈 화면 이름(`CFBundleDisplayName`)은 앱·위젯·워치 모두 `TV 리모컨`입니다.
- 설명 마지막 줄에 다음 문구를 넣으세요. 앱 설정 화면 하단에도 같은 문구가 있습니다.
  > 이 앱은 LG전자와 관련이 없는 독립 앱입니다. LG와 webOS는 LG전자의 상표입니다.

## 개인정보 처리방침

- URL: https://github.hellojyp.com/LG-TV-remote-controller/privacy.html — **앱 정보 > 개인정보 처리방침 URL**에 넣으세요.
- 지원 URL: https://github.hellojyp.com/LG-TV-remote-controller/
- 원문은 `docs/privacy.md` 하나입니다. GitHub Pages가 이 파일을 페이지로 만들고, 앱 설정 > 개인정보 처리방침도 빌드에 포함된 같은 파일을 보여 줍니다. 내용을 바꾸고 푸시하면 웹 페이지가 갱신되고, 앱은 다음 빌드부터 반영됩니다.

## 앱 개인정보 보호(개인정보 라벨)

**앱 개인정보 보호 > 데이터 수집** 질문에 다음과 같이 답합니다.

| 질문 | 답 |
|---|---|
| 이 앱에서 데이터를 수집합니까? | **아니요, 이 앱에서 데이터를 수집하지 않습니다** |

근거: TV 정보(이름, IP, MAC, 연결 키)는 기기 안에만 저장되고, 터치패드·버튼 입력은 같은 Wi-Fi의 TV로만 전달됩니다. Apple 기준으로 "수집"은 기기 밖 개발자나 제3자에게 전송하는 것을 말하므로 해당하지 않습니다. 앱과 위젯의 `PrivacyInfo.xcprivacy`도 수집 데이터 없음, 추적 없음으로 선언되어 있어 라벨과 일치합니다.

## 수출 규정(암호화)

앱·위젯·워치의 Info.plist에 `ITSAppUsesNonExemptEncryption = NO`가 들어 있어 업로드 후 별도 질문 없이 심사로 넘어갑니다. 표준 TLS(wss)만 사용하므로 면제 대상입니다.

## Apple Watch

- 스크린샷(Apple Watch Ultra, 422×514): `docs/screenshots/watch-1-navigation.png`, `docs/screenshots/watch-2-volume.png`
  - App Store Connect의 **Apple Watch** 스크린샷 칸에 올립니다.
- 설명에 다음 문구를 넣으세요.
  > Apple Watch 앱은 아이폰의 TV 리모컨 앱이 필요합니다. 워치에서 누른 버튼은 아이폰을 거쳐 TV로 전달되므로, 아이폰이 워치 근처에 있고 TV와 같은 Wi-Fi에 연결되어 있어야 합니다.
