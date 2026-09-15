import AppKit
import SwiftUI

/// 메뉴바 아이콘을 누르면 뜨는 재생 화면. 생김새는 PopoverStyle이 고른다.
struct NowPlayingView: View {
    @ObservedObject var model: PlayerModel
    let style: PopoverStyle
    /// 창을 띄울 때 정한 크기. 열려 있는 동안 곡이 바뀌어도 폭은 그대로 둔다.
    let size: CGSize

    var body: some View {
        content
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .track(let track):
            switch style {
            case .coverBleed: CoverBleedView(model: model, track: track)
            case .poster: PosterView(model: model, track: track)
            case .strip: StripView(model: model, track: track)
            }

        case .needsPermission:
            message(
                symbol: "exclamationmark.triangle.fill",
                text: "Spotify를 제어할 권한이 필요합니다",
                button: "자동화 권한 열기",
                action: openAutomationSettings
            )

        case .notRunning:
            message(
                symbol: "music.note",
                text: "Spotify가 실행 중이 아닙니다",
                button: "Spotify 열기",
                action: model.openSpotify
            )

        case .idle:
            message(
                symbol: "music.note",
                text: "재생 중인 곡이 없습니다",
                button: "Spotify 열기",
                action: model.openSpotify
            )
        }
    }

    private func message(symbol: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(text).font(.system(size: 13))
            Button(button, action: action).buttonStyle(PressableStyle(pressedScale: 0.94))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(model.accent.opacity(0.10))
    }

    private func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
}

extension SpotifyState.Track {
    /// 제목 아래 붙는 줄. 앨범을 모르는 곡이면 아티스트만 남는다.
    var subtitle: String {
        album.isEmpty ? artist : "\(artist) – \(album)"
    }
}
