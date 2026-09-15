# Spotify MenuBar

macOS 메뉴바에 Spotify에서 재생 중인 곡을 `노래 - 가수` 형태로 보여주는 앱.

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
실수로 거부했다면 메뉴바 아이콘이 `권한 필요`로 바뀌고, 메뉴의 **자동화 권한 열기…** 항목이 시스템 설정의 해당 화면을 열어 준다.

## 기능

- 재생 중인 곡을 `노래 - 가수`로 표시. 재생/일시정지 상태를 아이콘으로 구분한다.
- 메뉴에서 재생·일시정지, 이전 곡, 다음 곡, Spotify 창 열기.
- **표시 길이**: 메뉴바를 너무 차지하지 않도록 20/30/40/60자 중에서 고른다. 넘으면 뒤를 잘라 `…`을 붙인다.
- **로그인 시 자동 실행**: `SMAppService`로 등록한다.
- Dock 아이콘 없이 메뉴바에만 머문다 (`LSUIElement`).

## 동작 방식

곡 정보는 두 경로로 얻는다.

1. **Distributed notification** — Spotify가 재생 상태가 바뀔 때마다 `com.spotify.client.PlaybackStateChanged`를 브로드캐스트한다. payload에 곡 이름·아티스트·재생 상태가 들어 있어 이것만으로 즉시 갱신되고, 자동화 권한도 필요 없다.
2. **AppleScript 폴링(5초)** — 알림이 오지 않는 변화를 메운다. 앱 시작 시점의 현재 곡, Spotify 종료·재실행, 알림 유실이 여기에 해당한다.

`SpotifyController`가 이 둘을 하나의 `SpotifyState`로 합치고, 상태가 실제로 바뀔 때만 `StatusBarController`에 알린다. AppleScript 호출은 메뉴바가 멈추지 않도록 전용 직렬 큐에서 돈다.

## 구조

```
Sources/SpotifyMenuBar/
  main.swift                 앱 진입점, .accessory 정책 설정
  SpotifyController.swift    Spotify 상태 추적 및 재생 제어
  StatusBarController.swift  메뉴바 아이템 제목과 메뉴
Resources/Info.plist         LSUIElement, 자동화 권한 사용 설명
scripts/build.sh             SwiftPM 실행 파일을 .app 번들로 조립
scripts/install.sh           Applications로 설치 후 실행
```

## 알려진 제약

- Spotify **데스크톱 앱** 전용이다. 웹 플레이어나 휴대폰에서 재생 중인 곡은 읽지 못한다.
- ad-hoc 서명(`codesign -s -`)을 쓰기 때문에 다시 빌드하면 서명이 달라져 자동화 권한을 한 번 더 물어볼 수 있다.
