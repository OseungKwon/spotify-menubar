import SwiftUI

/// 커버를 크게 블러해 배경으로 깔고, 그 위에 흰 글자를 올린다.
///
/// 앨범마다 화면 전체의 색이 바뀌는 대신 글자색은 늘 흰색으로 고정한다.
/// 커버가 어떤 색이든 스크림 위에서는 흰 글자가 읽힌다.
struct CoverBleedView: View {
    @ObservedObject var model: PlayerModel
    let track: SpotifyState.Track

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 14) {
                ArtworkButton(image: model.artwork, side: 104, cornerRadius: 10, action: model.openTrackInSpotify)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                info
            }
            .padding(14)

            EdgeProgress(
                position: model.position,
                duration: track.duration,
                tint: .white,
                onScrub: model.scrub(to:),
                onCommit: model.commitScrub(to:)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 배경은 .background로 붙인다. 형제 뷰로 두면 커버의 원래 크기가
        // 레이아웃을 밀어내서 글자와 조작부가 화면 밖으로 나간다.
        .background(background)
    }

    private var background: some View {
        Color.clear
            .background(backdrop)
            .overlay(Color.black.opacity(0.42))
    }

    @ViewBuilder
    private var backdrop: some View {
        if let artwork = model.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .blur(radius: 55, opaque: true)
        } else {
            model.accent
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    MarqueeText(
                        text: track.name,
                        font: .systemFont(ofSize: 15, weight: .semibold),
                        color: .white
                    )
                    MarqueeText(
                        text: track.subtitle,
                        font: .systemFont(ofSize: 12),
                        color: .white.opacity(0.72)
                    )
                }
                EqualizerBars(isPlaying: track.isPlaying)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 4)

            HStack(spacing: 0) {
                TransportControls(model: model, isPlaying: track.isPlaying, tint: .white, spacing: 8)
                Spacer(minLength: 8)
                TimeLabels(
                    position: model.position,
                    duration: track.duration,
                    tint: .white.opacity(0.65)
                )
                .fixedSize()
            }
        }
    }
}
