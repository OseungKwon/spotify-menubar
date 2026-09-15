import SwiftUI

/// 한 줄로 눕힌 띠. 곡을 확인하고 넘기는 데만 필요한 것만 남긴다.
struct StripView: View {
    @ObservedObject var model: PlayerModel
    let track: SpotifyState.Track

    var body: some View {
        ZStack(alignment: .bottom) {
            model.accent.opacity(0.12)

            HStack(spacing: 12) {
                ArtworkButton(image: model.artwork, side: 52, cornerRadius: 7, action: model.openTrackInSpotify)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                VStack(alignment: .leading, spacing: 1) {
                    MarqueeText(text: track.name, font: .systemFont(ofSize: 13.5, weight: .semibold))
                    MarqueeText(text: track.subtitle, font: .systemFont(ofSize: 11.5), color: .secondary)
                }

                Text("−" + TimeLabels.clock(max(track.duration - model.position, 0)))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()

                TransportControls(model: model, isPlaying: track.isPlaying, scale: 0.85, spacing: 2)
                    .fixedSize()
            }
            .padding(.horizontal, 13)
            .padding(.bottom, 6)

            EdgeProgress(
                position: model.position,
                duration: track.duration,
                tint: model.accent,
                trackTint: Color.primary.opacity(0.14),
                onScrub: model.scrub(to:),
                onCommit: model.commitScrub(to:)
            )
        }
    }
}
