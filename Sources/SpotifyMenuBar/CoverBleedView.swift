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

    private static let inset: CGFloat = 16
    /// 커버와 글자 사이. 바깥 여백보다 좁다. 곧은 모서리와 달리 원은 위아래로
    /// 멀어지기 때문에, 같은 값을 주면 이쪽이 더 벌어져 보인다.
    private static let coverGap: CGFloat = 12
    /// 글 묶음과 조작부 사이.
    private static let blockGap: CGFloat = 10
    private static let ring: CGFloat = 104
    /// 버튼 프레임과 글리프의 좌우 여백 차이.
    private static let glyphInset: CGFloat = 7
    private static let titleFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    private static let subtitleFont = NSFont.systemFont(ofSize: 12)

    /// 글자 칸의 폭. 아래는 조작부 한 줄이 딱 들어가는 값이고, 위는 더 늘려도
    /// 읽기 좋아지지 않는 선에서 끊는다.
    private static let infoRange: ClosedRange<CGFloat> = 113...210

    /// 곡 제목에 맞춰 폭을 정한다. 고정 폭으로 두면 짧은 제목에서 오른쪽이
    /// 휑해져 좌우 여백이 달라 보인다.
    static func size(for track: SpotifyState.Track?) -> CGSize {
        let text = max(
            width(track?.name ?? "", titleFont),
            width(track?.subtitle ?? "", subtitleFont)
        )
        let info = min(max(text, infoRange.lowerBound), infoRange.upperBound)
        return CGSize(width: inset + ring + coverGap + info + inset, height: 136)
    }

    private static func width(_ text: String, _ font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    var body: some View {
        HStack(spacing: Self.coverGap) {
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
            VStack(alignment: .leading, spacing: 2) {
                LinkedTitle(
                    text: track.name,
                    font: .systemFont(ofSize: 15, weight: .semibold),
                    color: .white,
                    action: model.openTrackInSpotify
                )
                MarqueeText(
                    text: track.subtitle,
                    font: .systemFont(ofSize: 12),
                    color: .white.opacity(0.72)
                )
            }

            TransportControls(model: model, isPlaying: track.isPlaying, tint: .white, justified: true)
                // 버튼은 누를 자리를 넓히려고 글리프보다 프레임이 크다. 좌우로
                // 그만큼 넓혀야 글리프가 글자와 같은 선에서 시작하고 끝난다.
                .padding(.horizontal, -Self.glyphInset)
        }
    }
}
