import SwiftUI

/// 재생 중임을 알리는 작은 막대 네 개. 멈추면 사라진다.
struct EqualizerBars: View {
    let isPlaying: Bool

    private static let bars: [(peak: CGFloat, duration: Double)] = [
        (9, 0.52), (14, 0.68), (7, 0.44), (12, 0.60),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(Self.bars.enumerated()), id: \.offset) { _, bar in
                Bar(isPlaying: isPlaying, peak: bar.peak, duration: bar.duration)
            }
        }
        .frame(height: 14, alignment: .bottom)
        // 멈춘 동안 바닥에 눕혀 두면 점 네 개처럼 보여서 아예 감춘다.
        .opacity(isPlaying ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: isPlaying)
    }

    private struct Bar: View {
        let isPlaying: Bool
        let peak: CGFloat
        let duration: Double
        @State private var raised = false

        var body: some View {
            Capsule()
                .frame(width: 2.5, height: raised ? peak : 3)
                .onAppear { sync(isPlaying) }
                .onChange(of: isPlaying) { sync($0) }
        }

        private func sync(_ playing: Bool) {
            if playing {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    raised = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) { raised = false }
            }
        }
    }
}
