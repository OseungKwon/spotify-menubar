import AppKit
import SwiftUI

/// 메뉴바 아이콘을 누르면 뜨는 재생 화면.
struct NowPlayingView: View {
    @ObservedObject var model: PlayerModel

    static let size = CGSize(width: 372, height: 154)
    private static let artworkSide: CGFloat = 126

    var body: some View {
        ZStack {
            background
            content.padding(14)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    /// 커버에서 뽑은 색을 옅게 깔아 앨범마다 다른 인상을 준다.
    private var background: some View {
        LinearGradient(
            colors: [model.accent.opacity(0.20), model.accent.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.4), value: model.accent)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .track(let track):
            player(track)
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

    // MARK: - 재생 화면

    private func player(_ track: SpotifyState.Track) -> some View {
        HStack(spacing: 14) {
            ArtworkView(image: model.artwork, side: Self.artworkSide, action: model.openTrackInSpotify)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(text: track.name, font: .systemFont(ofSize: 15, weight: .bold))
                        MarqueeText(text: subtitle(track), font: .systemFont(ofSize: 12), color: .secondary)
                    }
                    EqualizerBars(isPlaying: track.isPlaying)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 6)
                controls(track).frame(maxWidth: .infinity)
                Spacer(minLength: 6)

                ProgressBar(
                    position: model.position,
                    duration: track.duration,
                    accent: model.accent,
                    onScrub: model.scrub(to:),
                    onCommit: model.commitScrub(to:)
                )
            }
        }
    }

    private func subtitle(_ track: SpotifyState.Track) -> String {
        track.album.isEmpty ? track.artist : "\(track.artist) – \(track.album)"
    }

    private func controls(_ track: SpotifyState.Track) -> some View {
        HStack(spacing: 22) {
            ControlButton(symbol: "backward.fill", size: 17, action: model.previousTrack)
            ControlButton(
                symbol: track.isPlaying ? "pause.fill" : "play.fill",
                size: 25,
                action: model.playPause
            )
            ControlButton(symbol: "forward.fill", size: 17, action: model.nextTrack)
        }
    }

    private func message(symbol: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text(text).font(.system(size: 13))
            Button(button, action: action)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - 부품

private struct ArtworkView: View {
    let image: NSImage?
    let side: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 26))
                                .foregroundStyle(.secondary)
                        )
                }
                if hovering {
                    Color.black.opacity(0.28)
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Spotify에서 열기")
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(.primary)
                .opacity(hovering ? 0.6 : 1)
                // play와 pause는 폭이 달라서, 바꿔도 버튼이 흔들리지 않게 자리를 고정한다.
                .frame(width: size * 1.6, height: size * 1.3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// 남은 시간을 함께 보여 주는 진행 바. 끌어서 원하는 지점으로 옮길 수 있다.
private struct ProgressBar: View {
    let position: Double
    let duration: Double
    let accent: Color
    let onScrub: (Double) -> Void
    let onCommit: (Double) -> Void

    private static let barHeight: CGFloat = 5

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(0, geometry.size.width * fraction))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { onScrub(seconds(at: $0.location.x, width: geometry.size.width)) }
                        .onEnded { onCommit(seconds(at: $0.location.x, width: geometry.size.width)) }
                )
            }
            .frame(height: Self.barHeight)

            HStack {
                Text(Self.clock(position))
                Spacer()
                Text("−" + Self.clock(max(duration - position, 0)))
            }
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    private func seconds(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return min(max(Double(x / width), 0), 1) * duration
    }

    private static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
