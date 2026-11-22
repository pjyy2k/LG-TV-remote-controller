# TV 리모컨 - LG webOS TV용 (iOS)

같은 Wi-Fi에 있는 LG webOS TV(2014년 이후 모델)를 아이폰으로 제어하는 SwiftUI 앱입니다.
LG 공식 앱과 같은 webOS SSAP 프로토콜(WebSocket, 포트 3001 wss / 3000 ws)을 사용합니다.

## 기능

- 리모컨: 전원, 방향키/확인, 뒤로/홈/설정, 음량(길게 누르면 연속)·음소거, 채널, 숫자패드, 재생 제어, 컬러 버튼
- 앱·입력: TV에 설치된 앱 실행, HDMI 등 외부 입력 전환
- 터치패드: 매직 리모컨처럼 포인터 이동·클릭·스크롤
- 키보드 입력: TV에 시스템 키보드가 뜨면 아이폰에 입력 팝업이 자동으로 뜹니다(전송 / 취소·뒤로). YouTube처럼 앱이 자체 화면 키보드를 쓰는 경우는 외부에서 입력할 방법이 없어 지원하지 않습니다.
- TV 자동 검색(서브넷 스캔) 또는 IP 직접 입력, 한 번 허용하면 이후 자동 연결
- 홈 화면 위젯(소형·중형): 전원, 음량, 음소거, 홈, 뒤로
- Apple Watch: 방향키·확인·뒤로·홈·전원·음소거, 음량·채널·재생 제어, 디지털 크라운으로 음량 조절. watchOS는 일반 앱의 WebSocket 연결을 막아서, 워치가 명령을 아이폰에 보내면 아이폰이 TV로 전달합니다(아이폰이 근처에 있어야 함).

App Store 제출 준비는 [docs/APP_STORE_SUBMISSION.md](docs/APP_STORE_SUBMISSION.md)를 보세요. 이 앱은 LG전자와 관련이 없는 독립 앱입니다. LG와 webOS는 LG전자의 상표입니다.

## 빌드 방법

1. Mac App Store에서 **Xcode**를 설치합니다(현재 Mac에는 Command Line Tools만 있습니다).
2. `LGRemote.xcodeproj`를 엽니다. 파일 구성을 바꾼 뒤에는 `xcodegen generate`로 프로젝트를 다시 만드세요(`project.yml`이 원본입니다).
3. `LGRemote`, `LGRemoteWidget`, `LGRemoteWatch` 세 타깃 모두 Signing & Capabilities에서 Team을 본인 Apple ID로 선택합니다(7일마다 재설치 필요).
   위젯은 App Group(`group.com.jinyoung.lgremote`)으로 앱과 저장된 TV 정보를 공유합니다. 서명 오류가 나면 두 타깃의 App Groups 항목에서 같은 그룹을 체크하세요.
   `xcodegen generate`를 다시 실행하면 Xcode에서 고른 Team이 초기화되니, `project.yml`의 `settings.base`에 `DEVELOPMENT_TEAM: <팀 ID>`를 넣어 두면 편합니다.
4. 아이폰을 연결해 실행합니다. 처음 실행할 때 **로컬 네트워크 접근 허용**을 눌러야 합니다.

## 처음 연결

1. 앱에서 검색된 TV를 고르거나 IP를 입력합니다(TV: 설정 > 일반 > 네트워크에서 확인).
2. TV 화면에 뜨는 연결 요청에서 **허용**을 누릅니다.

## 알려진 제약

- **꺼진 TV 켜기(Wake-on-LAN)**: TV에서 "모바일로 TV 켜기"를 켜 두어야 합니다. iOS는 브로드캐스트 패킷을 보내려면
  Apple의 `com.apple.developer.networking.multicast` 권한을 요구하므로, 이 권한 없이는 켜기 신호가 막힐 수 있습니다.
  TV를 끄는 기능과 TV가 켜져 있을 때의 모든 제어는 이 권한 없이 동작합니다.
- 실제 TV에서는 아직 테스트하지 않았습니다. 코드는 macOS SDK로 타입체크만 했습니다.
