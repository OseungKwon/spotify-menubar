import AppKit
import SwiftUI

// MARK: - 촉감

/// 누르는 순간 즉시 작아지고, 떼면 살짝 튕기며 돌아온다.
///
/// 감쇠를 0.55로 낮춰 복귀에 약간의 오버슛을 남겼다. 1에 가까우면 얌전하지만
/// 눌렀다는 느낌이 남지 않는다.
struct PressableStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.88

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

extension View {
    /// 호버 상태를 부드럽게 넘겨 준다. 켜고 끄는 시점이 딱 끊기면 값싸 보인다.
    func smoothHover(_ handler: @escaping (Bool) -> Void) -> some View {
        onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) { handler(hovering) }
        }
    }
}

// MARK: - 조작

/// 이전 곡 / 재생·일시정지 / 다음 곡.
struct TransportControls: View {
    let model: PlayerModel
    let isPlaying: Bool
    var tint: Color = .primary
    var scale: CGFloat = 1
    var spacing: CGFloat = 20

    var body: some View {
        HStack(spacing: spacing) {
            TransportButton(symbol: "backward.fill", size: 15 * scale, tint: tint, action: model.previousTrack)
            TransportButton(
                symbol: isPlaying ? "pause.fill" : "play.fill",
                size: 21 * scale,
                tint: tint,
                action: model.playPause
            )
            TransportButton(symbol: "forward.fill", size: 15 * scale, tint: tint, action: model.nextTrack)
        }
    }
}

private struct TransportButton: View {
    let symbol: String
    let size: CGFloat
    let tint: Color
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint)
                // play와 pause는 폭이 달라서, 바꿔도 버튼이 흔들리지 않게 자리를 고정한다.
                .frame(width: size * 2.1, height: size * 2.1)
                .background(Circle().fill(tint.opacity(hovering ? 0.15 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .smoothHover { hovering = $0 }
    }
}

/// 누르면 그 곡을 Spotify에서 여는 앨범 커버.
struct ArtworkButton: View {
    let image: NSImage?
    let side: CGFloat
    let cornerRadius: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary).overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: side * 0.24))
                            .foregroundStyle(.secondary)
                    )
                }
                Color.black.opacity(hovering ? 0.3 : 0)
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: side * 0.17, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(hovering ? 1 : 0)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle(pressedScale: 0.96))
        .smoothHover { hovering = $0 }
        .help("Spotify에서 열기")
    }
}

// MARK: - 시간

/// 경과 시간과 남은 시간.
struct TimeLabels: View {
    let position: Double
    let duration: Double
    var tint: Color = .secondary
    var size: CGFloat = 11

    var body: some View {
        HStack {
            Text(Self.clock(position))
            Spacer(minLength: 8)
            Text("−" + Self.clock(max(duration - position, 0)))
        }
        .font(.system(size: size).monospacedDigit())
        .foregroundStyle(tint)
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - 진행

/// 끌어서 옮길 수 있는 진행 바. 마우스를 올리면 도톰해지고 손잡이가 나온다.
struct ProgressBar: View {
    let position: Double
    let duration: Double
    let tint: Color
    var trackTint: Color = Color.primary.opacity(0.15)
    let onScrub: (Double) -> Void
    let onCommit: (Double) -> Void

    @State private var hovering = false
    @State private var dragging = false

    private var thickness: CGFloat { hovering || dragging ? 7 : 4 }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(trackTint)
                Capsule().fill(tint).frame(width: max(0, geometry.size.width * fraction(duration, position)))
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .frame(width: thickness + 4, height: thickness + 4)
                    .offset(x: geometry.size.width * fraction(duration, position) - (thickness + 4) / 2)
                    .opacity(hovering || dragging ? 1 : 0)
            }
            .frame(height: thickness)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging { withAnimation(.easeOut(duration: 0.12)) { dragging = true } }
                        onScrub(seconds(at: value.location.x, width: geometry.size.width, duration: duration))
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.18)) { dragging = false }
                        onCommit(seconds(at: value.location.x, width: geometry.size.width, duration: duration))
                    }
            )
            .animation(.easeOut(duration: 0.18), value: thickness)
        }
        // 손잡이가 커져도 잘리지 않도록 만지는 영역을 바보다 넉넉히 잡는다.
        .frame(height: 14)
        .smoothHover { hovering = $0 }
    }
}

/// 팝오버 맨 아래 가장자리를 가로지르는 진행 표시. 바 하나를 지면에서 없앤다.
struct EdgeProgress: View {
    let position: Double
    let duration: Double
    let tint: Color
    /// 밝은 커버 위에서는 흰 선이 묻힌다. 바탕을 어둡게 깔아 대비를 확보한다.
    var trackTint: Color = .black.opacity(0.38)
    let onScrub: (Double) -> Void
    let onCommit: (Double) -> Void

    @State private var hovering = false
    @State private var dragging = false

    private var thickness: CGFloat { hovering || dragging ? 5 : 2.5 }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(trackTint)
                Rectangle()
                    .fill(tint)
                    .frame(width: max(0, geometry.size.width * fraction(duration, position)))
            }
            .frame(height: thickness)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging { withAnimation(.easeOut(duration: 0.12)) { dragging = true } }
                        onScrub(seconds(at: value.location.x, width: geometry.size.width, duration: duration))
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.18)) { dragging = false }
                        onCommit(seconds(at: value.location.x, width: geometry.size.width, duration: duration))
                    }
            )
            .animation(.easeOut(duration: 0.18), value: thickness)
        }
        .frame(height: 12)
        .smoothHover { hovering = $0 }
    }
}

private func fraction(_ duration: Double, _ position: Double) -> Double {
    guard duration > 0 else { return 0 }
    return min(max(position / duration, 0), 1)
}

private func seconds(at x: CGFloat, width: CGFloat, duration: Double) -> Double {
    guard width > 0 else { return 0 }
    return min(max(Double(x / width), 0), 1) * duration
}
