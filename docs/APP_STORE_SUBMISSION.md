# App Store 제출 준비

코드와 빌드 쪽 준비는 끝났습니다. 아래는 App Store Connect에서 직접 입력해야 하는 항목입니다.

## 앱 이름과 상표

- 앱 이름(App Store): `심플 TV 리모컨 for LG webOS` (언어별 이름은 아래 표)
  - "광고 없음"은 이름이 아니라 부제에 넣습니다. Apple은 앱 이름에 가격·광고 같은 설명어를 넣는 것을 금지합니다(가이드라인 2.3.7).
  - "LG"로 시작하는 이름은 LG전자 허가 없이 쓰면 거절될 수 있어, 호환 대상을 설명하는 형태로만 씁니다.
- 기기 홈 화면 이름(`CFBundleDisplayName`)은 앱·위젯·워치 모두 `TV 리모컨`입니다.
- 설명 마지막 줄에 다음 문구를 넣으세요. 앱 설정 화면 하단에도 같은 문구가 있습니다.
  > 이 앱은 LG전자와 관련이 없는 독립 앱입니다. LG와 webOS는 LG전자의 상표입니다.

## 개인정보 처리방침

- URL: https://pjyy2k.github.io/LG-TV-remote-controller/privacy.html — **앱 정보 > 개인정보 처리방침 URL**에 넣으세요.
- 지원 URL: https://pjyy2k.github.io/LG-TV-remote-controller/
- 원문은 `docs/privacy.md` 하나입니다. GitHub Pages가 이 파일을 페이지로 만들고, 앱 설정 > 개인정보 처리방침도 빌드에 포함된 같은 파일을 보여 줍니다. 내용을 바꾸고 푸시하면 웹 페이지가 갱신되고, 앱은 다음 빌드부터 반영됩니다.

## 앱 개인정보 보호(개인정보 라벨)

**앱 개인정보 보호 > 데이터 수집** 질문에 다음과 같이 답합니다.

| 질문 | 답 |
|---|---|
| 이 앱에서 데이터를 수집합니까? | **아니요, 이 앱에서 데이터를 수집하지 않습니다** |

근거: TV 정보(이름, IP, MAC, 연결 키)는 기기 안에만 저장되고, 터치패드·버튼 입력은 같은 Wi-Fi의 TV로만 전달됩니다. Apple 기준으로 "수집"은 기기 밖 개발자나 제3자에게 전송하는 것을 말하므로 해당하지 않습니다. 앱과 위젯의 `PrivacyInfo.xcprivacy`도 수집 데이터 없음, 추적 없음으로 선언되어 있어 라벨과 일치합니다.

## 수출 규정(암호화)

앱·위젯·워치의 Info.plist에 `ITSAppUsesNonExemptEncryption = NO`가 들어 있어 업로드 후 별도 질문 없이 심사로 넘어갑니다. 표준 TLS(wss)만 사용하므로 면제 대상입니다.

## 출시 국가와 언어

앱은 한국어(기본), 영어, 일본어를 지원합니다. 기기 언어가 이 세 가지가 아니면 한국어로 표시됩니다.

- **가격 및 사용 가능 여부 > 국가 또는 지역**에서 대한민국, 미국, 일본을 고릅니다.
- **중국 본토는 반드시 해제합니다.** MIIT 앱 등록(ICP 번호) 없이는 출시할 수 없고, 등록은 중국 법인이나 현지 대행사를 통해서만 가능합니다.
- App Store Connect의 기본 언어를 한국어로 두고, **영어(미국)**과 **일본어** 현지화를 추가해 아래 내용을 넣습니다. 스크린샷은 각 언어로 설정한 기기나 시뮬레이터에서 찍습니다.

| 항목 | 한국어 | English (U.S.) | 日本語 |
|---|---|---|---|
| 앱 이름 | 심플 TV 리모컨 for LG webOS | Simple TV Remote for LG webOS | シンプルTVリモコン for LG webOS |
| 부제 | 광고 없이 누르면 바로 되는 리모컨 | No ads. Just a clean remote. | 広告なし、すぐ使えるリモコン |
| 키워드 | 리모컨,티비,webOS,스마트TV,위젯,워치 | remote,tv,webos,smart tv,widget,watch,control | リモコン,テレビ,webOS,スマートTV,ウィジェット,ウォッチ |
| 처리방침 URL | 아래 URL(한·영·일 모두 포함) | 같음 | 같음 |

설명 끝에는 언어별로 다음 문구를 넣습니다.

- English: This is an independent app and is not affiliated with LG Electronics. LG and webOS are trademarks of LG Electronics. The Apple Watch app requires the iPhone app; your iPhone must be nearby and on the same Wi-Fi as the TV.
- 日本語: このアプリはLGエレクトロニクスとは関係のない独立したアプリです。LGおよびwebOSはLGエレクトロニクスの商標です。Apple WatchアプリにはiPhoneアプリが必要です。iPhoneが近くにあり、TVと同じWi-Fiに接続されている必要があります。

## Apple Watch

- 스크린샷(Apple Watch Ultra, 422×514): `docs/screenshots/watch-1-navigation.png`, `docs/screenshots/watch-2-volume.png`
  - App Store Connect의 **Apple Watch** 스크린샷 칸에 올립니다.
- 설명에 다음 문구를 넣으세요.
  > Apple Watch 앱은 아이폰의 TV 리모컨 앱이 필요합니다. 워치에서 누른 버튼은 아이폰을 거쳐 TV로 전달되므로, 아이폰이 워치 근처에 있고 TV와 같은 Wi-Fi에 연결되어 있어야 합니다.
