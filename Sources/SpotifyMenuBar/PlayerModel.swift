import AppKit
import SwiftUI

/// SwiftUI 팝오버가 보는 재생 상태.
///
/// `SpotifyController`가 다루지 않는 화면 쪽 관심사, 즉 앨범 커버 로딩과
/// 진행 바를 매끄럽게 움직이는 일, 드래그 중 갱신을 막는 일을 맡는다.
final class PlayerModel: ObservableObject {
    @Published private(set) var state: SpotifyState = .notRunning
    @Published private(set) var artwork: NSImage?
    @Published private(set) var accent: Color = .accentColor
    /// 진행 바에 그릴 위치(초). 드래그 중에는 손가락을 따라간다.
    @Published private(set) var position: Double = 0

    let spotify: SpotifyController
    private var ticker: Timer?
    private var isScrubbing = false

    init(spotify: SpotifyController) {
        self.spotify = spotify
        spotify.onChange = { [weak self] state in self?.apply(state) }
        apply(spotify.state)
    }

    var track: SpotifyState.Track? { state.track }

    // MARK: - 팝오버 생명주기

    /// 팝오버가 열려 있는 동안에만 돌린다. 닫힌 창을 위해 초당 여러 번 깨울 이유가 없다.
    func startTicking() {
        spotify.setLive(true)
        ticker?.invalidate()
        let ticker = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, !self.isScrubbing else { return }
            self.position = self.spotify.position
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
        position = spotify.position
    }

    func stopTicking() {
        spotify.setLive(false)
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - 조작

    func playPause() { spotify.playPause() }
    func nextTrack() { spotify.nextTrack() }
    func previousTrack() { spotify.previousTrack() }
    func openTrackInSpotify() { spotify.openCurrentTrack() }
    func openSpotify() { spotify.activateSpotify() }

    func scrub(to seconds: Double) {
        isScrubbing = true
        position = seconds
    }

    func commitScrub(to seconds: Double) {
        position = seconds
        isScrubbing = false
        spotify.seek(to: seconds)
    }

    // MARK: -

    private func apply(_ state: SpotifyState) {
        let previous = self.state.track
        self.state = state
        if !isScrubbing { position = spotify.position }

        guard let url = state.track?.artworkURL else {
            if state.track == nil { artwork = nil }
            return
        }
        guard url != previous?.artworkURL || artwork == nil else { return }

        if let hit = Artwork.cached(url) {
            artwork = hit.image
            accent = Color(hit.accent)
            return
        }
        Artwork.load(url) { [weak self] image, accent in
            // 로딩이 끝나기 전에 곡이 또 넘어갔으면 버린다.
            guard let self, self.state.track?.artworkURL == url else { return }
            self.artwork = image
            self.accent = Color(accent)
        }
    }
}
