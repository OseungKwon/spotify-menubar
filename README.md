# Spotify MenuBar

macOS 메뉴바에서 Spotify로 지금 뭐가 나오는지 보고, 눌러서 넘기고 되감는 앱.

<!-- docs/images/hero.png : 메뉴바에 곡이 떠 있고 그 아래 재생 화면이 열린 전체 모습 -->
![](docs/images/hero.png)

## 왜 만들었나

곡 제목을 확인하려고 Spotify 창을 앞으로 꺼내는 일이 잦았다. 메뉴바에 `노래 - 가수`만 떠 있으면 그럴 일이 없다.
누르면 앨범 커버와 재생 컨트롤이 나오고, 그걸로 끝이다. 그 이상은 Spotify가 할 일이다.

## 요구 사항

- macOS 13 이상
- Swift 툴체인 (Xcode 또는 Command Line Tools)
- Spotify 데스크톱 앱

## 설치

```bash
git clone https://github.com/OseungKwon/spotify-menubar.git
cd spotify-menubar
make install
```

`build/SpotifyMenuBar.app`을 만들어 `/Applications`(쓰기 권한이 없으면 `~/Applications`)로 복사하고 실행한다.
빌드만 하려면 `make build`, 설치 없이 실행해 보려면 `make run`.

첫 실행 때 **"SpotifyMenuBar에서 Spotify을(를) 제어하도록 허용하시겠습니까?"** 대화상자가 뜬다. 허용해야 곡 정보를 읽을 수 있다.
실수로 거부했다면 메뉴바에 `권한 필요`가 뜨고, 재생 화면과 설정 메뉴에 시스템 설정을 여는 항목이 생긴다.

---

## 메뉴바

<!-- docs/images/menubar.png : 메뉴바 오른쪽에 "Little Riot - The Volunteers"가 떠 있는 모습 (다른 아이콘들과 함께) -->
![](docs/images/menubar.png)

아이콘 없이 글자만 둔다. 음표 같은 걸 앞에 붙이면 메뉴바에서 겉돈다.

| 상태 | 표시 |
|---|---|
| 재생 중 | `노래 - 가수` |
| 일시정지 | 같은 글자를 흐리게 |
| 재생 중인 곡 없음 | `Spotify`를 흐리게 |
| 권한 거부됨 | `권한 필요` |

곡이 없을 때 글자를 아예 비우면 누를 자리가 사라지기 때문에 앱 이름만 남긴다.
제목이 길면 기본 40자에서 자른다. 20 / 30 / 40 / 60자 중에 고를 수 있다.

## 재생 화면

메뉴바 아이템을 **왼쪽 클릭**하면 아래에 뜬다.

<!-- docs/images/player.png : 재생 화면 기본 상태 (원형 커버 + 진행 링 + 제목/아티스트 + 재생 버튼) -->
![](docs/images/player.png)

- **원형 커버와 진행 링** — 진행 바를 따로 두지 않고 커버 테두리가 그 역할을 한다. 링 위에서 끌면 그 지점으로 이동한다
- **제목을 누르면** 그 곡이 Spotify에서 열린다. 제목이 길면 옆으로 흘러간다
- **배경** — 커버를 크게 블러해서 깔고 그 위에 흰 글자를 올린다. 앨범마다 화면 전체 색이 바뀐다
- **폭** — 곡 제목 길이에 따라 262 ~ 358pt 사이를 오간다. 짧은 제목에서 오른쪽이 휑해 보이지 않게

커버 안쪽에서 시작한 드래그는 무시한다. 곡을 확인하려고 커버를 눌렀다가 재생 위치가 튀면 곤란하다.

### 시간은 만질 때만

<!-- docs/images/player-scrub.png : 링에 마우스를 올려 커버 위에 경과/전체 시간이 뜬 상태 -->
![](docs/images/player-scrub.png)

링에 마우스를 올리거나 끄는 동안에만 커버를 덮으며 뜬다. 위가 지금 위치, 아래가 곡 길이다.
진행은 링이 이미 보여 주고 있으니 숫자는 실제로 탐색할 때만 있으면 된다.

### 누르는 느낌

버튼은 누른 즉시 0.88배로 줄고, 떼면 살짝 튕기며 돌아온다. 스프링 감쇠를 0.55로 낮춰 복귀에 약간의 오버슛을 남겼다.
1에 가까우면 얌전하지만 눌렀다는 느낌이 남지 않는다. 호버는 0.18초에 걸쳐 원형 배경이 차오른다.

제목은 눌러도 크기를 줄이지 않고 밝기로만 반응한다. 글자가 가운데를 기준으로 줄어들면 왼쪽 끝이 밀려서 읽던 자리가 흔들린다.

## 설정 메뉴

메뉴바 아이템을 **오른쪽 클릭**(또는 control-클릭)하면 나온다.

<!-- docs/images/menu.png : 오른쪽 클릭으로 열린 설정 메뉴 -->
![](docs/images/menu.png)

- 이 곡 Spotify에서 열기 / Spotify 열기
- **재생 화면 디자인** — 아래 세 가지 중에서. 다음에 열 때부터 적용된다
- **메뉴바 표시 길이** — 20 / 30 / 40 / 60자
- **로그인 시 자동 실행** — `SMAppService`로 등록한다
- 종료

## 재생 화면 디자인

기본값은 **커버가 번지는 배경**이다.

<!-- docs/images/designs.png : 세 디자인을 나란히 놓은 비교 이미지 -->
![](docs/images/designs.png)

| 디자인 | 크기 | 성격 |
|---|---|---|
| 커버가 번지는 배경 | 262~358 × 136 | 폭이 곡 제목에 맞춰 늘고 준다. 원형 커버 테두리가 진행을 표시한다 |
| 포스터 | 320 × 300 | 커버를 상단 전면에 세우고 제목을 그 위에 얹는다 |
| 얇은 스트립 | 380 × 86 | 한 줄로 눕혀 높이를 절반으로 줄인다 |

---

## 동작 방식

### 곡 정보는 두 경로로 얻는다

| | Distributed Notification | AppleScript |
|---|---|---|
| 방식 | Spotify가 상태 변화를 쏜다 | 우리가 물어본다 |
| 자동화 권한 | 필요 없음 | 필요 |
| 시점 | 재생/일시정지/곡 변경 시 | 언제든 |

알림 payload에 곡 이름, 아티스트, 앨범, 길이, 재생 위치가 들어 있어 곡이 바뀌는 즉시 갱신된다.
payload에 없는 **앨범 커버 URL**만 AppleScript로 따로 물어본다.

폴링은 알림이 오지 않는 변화를 메운다. 앱 시작 시점의 현재 곡, Spotify 종료·재실행이 여기에 해당한다.
재생 화면이 열려 있으면 1.5초, 닫혀 있으면 5초 주기로 돈다.

`SpotifyController`가 둘을 하나의 `SpotifyState`로 합치고, 상태가 실제로 바뀔 때만 알린다.
AppleScript 호출은 메뉴바가 멈추지 않도록 전용 직렬 큐에서 돈다.

### 재생 위치는 보간한다

마지막으로 읽은 값과 읽은 시각을 함께 들고 있다가 그 사이를 채운다. 폴링 주기마다 진행 링이 뚝뚝 끊기지 않는다.

### 배경색은 커버에서 뽑는다

커버를 32×32로 줄인 뒤 채도와 밝기가 함께 높은 픽셀을 고른다.
평균색을 쓰면 대부분 흙빛 회색으로 수렴해서 앨범을 구분할 수 없다. 흑백 커버처럼 뽑을 색이 없으면 시스템 강조색에 맡긴다.

### 말풍선이 아니라 패널이다

`NSPopover`는 말풍선 부리를 항상 그리고 그 모양을 끌 수 없다. 테두리 없는 `NSPanel`을 직접 띄운다.

- 메뉴바 아이템 아래 8pt 띄워 세운다. 제어 센터를 비롯한 시스템 패널도 메뉴바에 붙지 않는다
- 화면이 떠 있는 동안 메뉴바 아이템은 눌린 상태로 남는다
- `nonactivatingPanel`이라 앞에 있던 앱의 포커스를 뺏지 않는다
- 바깥 클릭은 전역 이벤트 모니터로, 다른 앱 전환은 `windowDidResignKey`로 닫는다

닫을 때는 안에 든 SwiftUI 뷰를 통째로 버린다. 마키의 `repeatForever` 애니메이션은 창이 숨어도 멈추지 않아서, 한 번 열어 본 뒤로 CPU를 15%씩 먹었다.

## 구조

```
Sources/SpotifyMenuBar/
  main.swift                 진입점, Dock 아이콘 없이 .accessory로 띄운다
  SpotifyController.swift    Spotify 상태 추적과 재생 제어
  PlayerModel.swift          화면이 보는 상태. 커버 로딩, 진행 보간, 드래그 중 갱신 억제
  StatusBarController.swift  메뉴바 아이템, 패널 여닫기, 설정 메뉴
  PlayerPanel.swift          테두리 없는 창과 그 위치 계산
  NowPlayingView.swift       고른 디자인으로 넘기고, 곡이 없을 때 화면을 그린다
  PopoverStyle.swift         디자인 종류와 크기
  CoverBleedView.swift       디자인: 커버가 번지는 배경
  PosterView.swift           디자인: 포스터
  StripView.swift            디자인: 얇은 스트립
  PlayerParts.swift          조작부, 원형 커버와 진행 링, 누르는 느낌
  MarqueeText.swift          폭을 넘치는 글자를 흘려 보여 주는 뷰
  Artwork.swift              커버 내려받기와 대표색 추출

Resources/Info.plist         LSUIElement, 자동화 권한 사용 설명
scripts/build.sh             SwiftPM 실행 파일을 .app 번들로 조립
scripts/install.sh           Applications로 설치 후 실행
```

SwiftPM은 실행 파일만 내놓고 `Info.plist`를 담은 번들을 만들어 주지 않는다.
Xcode 프로젝트를 들이는 대신 `build.sh`에서 번들을 조립하고 ad-hoc으로 서명한다.
서명이 없으면 macOS가 자동화 권한을 기억하지 못한다.

## 알려진 제약

- Spotify **데스크톱 앱** 전용이다. 웹 플레이어나 휴대폰에서 재생 중인 곡은 읽지 못한다
- 좋아요 여부, 가사, 재생 큐는 AppleScript로 얻을 수 없다. Spotify Web API와 OAuth가 필요하다
- `popularity`와 `played count`는 현재 클라이언트가 항상 `0`으로 준다. `starred`는 없어진 속성이다
- ad-hoc 서명이라 다시 빌드하면 서명이 달라져 자동화 권한을 한 번 더 물어볼 수 있다

## 만들기

```bash
make build     # build/SpotifyMenuBar.app 생성
make run       # 빌드하고 실행
make install   # Applications로 설치하고 실행
make clean
```
