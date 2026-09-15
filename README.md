# Spotify MenuBar

macOS 메뉴바에 Spotify에서 재생 중인 곡을 `노래 - 가수` 형태로 보여주고, 누르면 앨범 커버와 진행 바가 있는 재생 화면을 띄우는 앱.

```
♪ TIME (all yours..) - The Volunteers
```

## 요구 사항

- macOS 13 이상
- Swift 툴체인 (Xcode 또는 Command Line Tools)
- Spotify 데스크톱 앱

## 설치

```bash
make install
```

`build/SpotifyMenuBar.app`을 만들어 `/Applications`(쓰기 권한이 없으면 `~/Applications`)로 복사하고 실행한다.
빌드만 하려면 `make build`, 설치 없이 실행해 보려면 `make run`.

첫 실행 때 **"SpotifyMenuBar에서 Spotify을(를) 제어하도록 허용하시겠습니까?"** 대화상자가 뜬다. 허용해야 곡 정보를 읽을 수 있다.
실수로 거부했다면 메뉴바 아이콘이 `권한 필요`로 바뀌고, 재생 화면과 설정 메뉴에 시스템 설정을 여는 항목이 생긴다.

## 기능

**메뉴바** — 재생 중인 곡을 `노래 - 가수`로 표시한다. 아이콘 없이 글자만 두고, 일시정지 중이면 흐리게 보여 준다. 재생 중인 곡이 없으면 누를 자리를 남기려고 `Spotify`만 흐리게 띄운다.

**왼쪽 클릭: 재생 화면**

공통으로 앨범 커버, 곡 제목, `아티스트 – 앨범`, 이전/재생·일시정지/다음, 진행과 남은 시간이 있다.
진행은 **끌어서 원하는 지점으로 옮길 수 있고**, 제목이 길면 옆으로 흘러간다.

배치는 세 가지 중에 고른다. 기본값은 첫 번째다.

| 디자인 | 크기 | 성격 |
|---|---|---|
| 커버가 번지는 배경 | 372×136 | 커버를 크게 블러해 배경으로 깔고 흰 글자를 올린다. 커버는 원이고, **그 테두리를 도는 링이 진행 표시**다. 링 위에서 끌면 이동한다 |
| 포스터 | 320×300 | 커버를 상단 전면에 세우고 제목을 그 위에 얹는다 |
| 얇은 스트립 | 380×86 | 한 줄로 눕혀 높이를 절반으로 줄인다 |

**누르는 느낌** — 버튼은 눌리는 순간 0.88배로 줄고 떼면 살짝 튕기며 돌아온다(스프링 감쇠 0.55).
호버는 0.18초에 걸쳐 원형 배경이 차오르고, 진행 바는 마우스를 올리면 도톰해지며 손잡이가 나타난다.

**오른쪽 클릭: 설정 메뉴**

- 재생 화면 디자인 (위 세 가지). 다음에 열 때부터 적용된다
- 이 곡 Spotify에서 열기
- 메뉴바 표시 길이(20/30/40/60자). 넘으면 뒤를 잘라 `…`을 붙인다
- 로그인 시 자동 실행 (`SMAppService`)
- Spotify 열기, 종료

Dock 아이콘 없이 메뉴바에만 머문다 (`LSUIElement`).

## 동작 방식

곡 정보는 두 경로로 얻는다.

1. **Distributed notification** — Spotify가 재생 상태가 바뀔 때마다 `com.spotify.client.PlaybackStateChanged`를 브로드캐스트한다. payload에 곡 이름·아티스트·앨범·길이·재생 위치가 들어 있어 이것만으로 즉시 갱신되고, 자동화 권한도 필요 없다.
2. **AppleScript 폴링** — 알림이 오지 않는 변화를 메운다. 앱 시작 시점의 현재 곡, Spotify 종료·재실행이 여기에 해당한다. payload에 없는 **앨범 커버 URL**도 이쪽으로 얻는다.

`SpotifyController`가 둘을 하나의 `SpotifyState`로 합치고, 상태가 실제로 바뀔 때만 알린다. AppleScript 호출은 메뉴바가 멈추지 않도록 전용 직렬 큐에서 돈다.

재생 위치는 마지막으로 읽은 값과 읽은 시각을 함께 들고 있다가 그 사이를 보간한다. 덕분에 폴링 주기(재생 화면이 열려 있으면 1.5초, 닫혀 있으면 5초)보다 진행 바가 부드럽게 움직인다.

## 구조

```
Sources/SpotifyMenuBar/
  main.swift                 앱 진입점, .accessory 정책 설정
  SpotifyController.swift    Spotify 상태 추적 및 재생 제어
  PlayerModel.swift          재생 화면이 보는 상태. 커버 로딩과 진행 바 보간
  StatusBarController.swift  메뉴바 아이템, 팝오버와 설정 메뉴
  NowPlayingView.swift       고른 디자인으로 넘기고, 곡이 없을 때 화면을 그린다
  PopoverStyle.swift         디자인 종류와 크기
  CoverBleedView.swift       디자인: 커버가 번지는 배경 (원형 커버 + 진행 링)
  PosterView.swift           디자인: 포스터
  StripView.swift            디자인: 얇은 스트립
  PlayerParts.swift          조작부·커버·진행 바 공통 부품과 누르는 느낌
  Artwork.swift              커버 내려받기와 대표색 추출
  MarqueeText.swift          폭을 넘치는 텍스트를 흘려 보여 주는 뷰
  EqualizerBars.swift        재생 중임을 알리는 막대
Resources/Info.plist         LSUIElement, 자동화 권한 사용 설명
scripts/build.sh             SwiftPM 실행 파일을 .app 번들로 조립
scripts/install.sh           Applications로 설치 후 실행
```

## 알려진 제약

- Spotify **데스크톱 앱** 전용이다. 웹 플레이어나 휴대폰에서 재생 중인 곡은 읽지 못한다.
- 좋아요 여부, 가사, 재생 큐는 AppleScript로 얻을 수 없다. Web API와 OAuth가 필요하다.
- `popularity`와 `played count`는 현재 클라이언트가 항상 `0`으로 준다.
- ad-hoc 서명(`codesign -s -`)을 쓰기 때문에 다시 빌드하면 서명이 달라져 자동화 권한을 한 번 더 물어볼 수 있다.
