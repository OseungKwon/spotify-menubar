# Spotify MenuBar

맥 메뉴바에서 지금 나오는 Spotify 곡을 보여주는 앱입니다.

<!-- docs/images/hero.png : 메뉴바에 곡이 떠 있고 그 아래 재생 화면이 열린 모습 -->
![](docs/images/hero.png)

- 메뉴바에 `노래 - 가수`가 뜹니다
- 누르면 앨범 커버와 재생 버튼이 나옵니다
- 곡을 넘기거나 원하는 지점으로 되감을 수 있습니다

## 설치

macOS 13 이상, Spotify 데스크톱 앱, [Xcode Command Line Tools](https://developer.apple.com/download/all/)가 필요합니다.

터미널에서 아래를 실행해 주세요.

```bash
git clone https://github.com/OseungKwon/spotify-menubar.git
cd spotify-menubar
make install
```

앱이 만들어져 `응용 프로그램`에 설치되고 바로 실행됩니다.

첫 실행 때 **"SpotifyMenuBar에서 Spotify을(를) 제어하도록 허용하시겠습니까?"** 창이 뜹니다.
허용해야 곡 정보를 읽어올 수 있습니다. 실수로 거부하셨다면 메뉴바에 `권한 필요`가 뜨는데, 그 글자를 누르면 시스템 설정으로 갈 수 있습니다.

## 쓰는 법

<!-- docs/images/player.png : 재생 화면 (원형 커버 + 진행 링 + 제목/아티스트 + 재생 버튼) -->
![](docs/images/player.png)

**메뉴바 글자를 클릭**하면 재생 화면이 열립니다.

- 커버 테두리의 링이 진행 상태를 나타냅니다. **링을 끌면** 그 지점으로 이동합니다
- 링에 마우스를 올리면 지금 위치와 곡 길이가 뜹니다
- **제목을 누르면** 그 곡이 Spotify에서 열립니다
- 일시정지 중에는 메뉴바 글자가 흐려집니다

**오른쪽 클릭**하면 설정이 나옵니다.

- 재생 화면 디자인 (3가지)
- 메뉴바에 표시할 글자 수 (20 / 30 / 40 / 60자)
- 로그인 시 자동 실행
- 종료

## 알아두기

- **Spotify 데스크톱 앱에서 재생 중일 때만** 동작합니다. 웹 플레이어나 휴대폰에서 듣는 곡은 읽어오지 못하니, 아무것도 뜨지 않는다면 이쪽을 확인해 보세요
- 좋아요, 가사, 재생 목록은 지원하지 않습니다
- 앱을 다시 빌드하면 권한을 한 번 더 물어볼 수 있습니다

## 명령어

```bash
make build     # 앱만 만들기
make run       # 만들고 실행
make install   # 응용 프로그램에 설치하고 실행
make clean
```
