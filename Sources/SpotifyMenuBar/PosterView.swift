import SwiftUI

/// 커버를 상단 전면에 세우고 제목을 그 위에 얹는다. 조작부는 아래 패널로 내린다.
struct PosterView: View {
    @ObservedObject var model: PlayerModel
    let track: SpotifyState.Track

    private static let coverHeight: CGFloat = 186

    var body: some View {
        VStack(spacing: 0) {
            cover
            panel
        }
    }

    private var cover: some View {
        Button(action: model.openTrackInSpotify) {
            // 커버를 형제 뷰로 두면 원래 크기가 레이아웃을 밀어내므로,
            // 빈 사각형에 배경으로 깔고 글자는 overlay로 얹는다.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.coverHeight)
                .background(artworkFill)
                .overlay(scrim, alignment: .bottom)
                .overlay(caption, alignment: .bottomLeading)
                .clipped()
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(pressedScale: 0.99))
        .help("Spotify에서 열기")
    }

    @ViewBuilder
    private var artworkFill: some View {
        if let artwork = model.artwork {
            Image(nsImage: artwork).resizable().scaledToFill()
        } else {
            model.accent.opacity(0.5)
        }
    }

    /// 커버 아래쪽을 어둡게 깔아야 어떤 앨범에서도 제목이 읽힌다.
    private var scrim: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.45), .black.opacity(0.82)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 96)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            MarqueeText(
                text: track.name,
                font: .systemFont(ofSize: 16, weight: .semibold),
                color: .white
            )
            MarqueeText(
                text: track.subtitle,
                font: .systemFont(ofSize: 12),
                color: .white.opacity(0.72)
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var panel: some View {
        VStack(spacing: 8) {
            TransportControls(model: model, isPlaying: track.isPlaying, scale: 1.15, spacing: 26)
            ProgressBar(
                position: model.position,
                duration: track.duration,
                tint: model.accent,
                onScrub: model.scrub(to:),
                onCommit: model.commitScrub(to:)
            )
            TimeLabels(position: model.position, duration: track.duration)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(model.accent.opacity(0.13))
    }
}
