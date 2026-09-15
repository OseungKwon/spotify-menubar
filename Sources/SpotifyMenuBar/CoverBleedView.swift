import SwiftUI

/// 커버를 크게 블러해 배경으로 깔고, 그 위에 흰 글자를 올린다.
///
/// 앨범마다 화면 전체의 색이 바뀌는 대신 글자색은 늘 흰색으로 고정한다.
/// 커버가 어떤 색이든 스크림 위에서는 흰 글자가 읽힌다.
///
/// 진행 표시는 커버 테두리를 도는 링이 맡는다. 팝오버 아래 가장자리에 선을
/// 그으면 모서리 라운드에 끝이 잘려 보였다.
struct CoverBleedView: View {
    @ObservedObject var model: PlayerModel
    let track: SpotifyState.Track

    /// 바깥 여백과 두 칸 사이 간격에 같은 값을 쓴다.
    private static let inset: CGFloat = 16
    /// 글 묶음과 조작부 사이.
    private static let blockGap: CGFloat = 10
    private static let ring: CGFloat = 104
    /// 버튼 프레임과 글리프의 좌우 여백 차이.
    private static let glyphInset: CGFloat = 7

    var body: some View {
        HStack(spacing: Self.inset) {
            RingArtwork(
                image: model.artwork,
                diameter: Self.ring,
                position: model.position,
                duration: track.duration,
                tint: .white,
                onScrub: model.scrub(to:),
                onCommit: model.commitScrub(to:)
            )
            info
        }
        .padding(Self.inset)
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

    /// 커버와 나란히 가운데 정렬한다. 남는 높이를 Spacer로 밀어내면
    /// 제목과 조작부가 팝오버 위아래 끝으로 갈라져 멀어 보인다.
    private var info: some View {
        VStack(alignment: .leading, spacing: Self.blockGap) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
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

            HStack(spacing: 0) {
                TransportControls(model: model, isPlaying: track.isPlaying, tint: .white, spacing: 6)
                    // 버튼은 누를 자리를 넓히려고 글리프보다 프레임이 크다. 그대로 두면
                    // 첫 버튼이 제목보다 안쪽으로 들어가 보여서 그만큼 당긴다.
                    .offset(x: -Self.glyphInset)
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
