import AppKit
import SwiftUI

// MARK: - 촉감

/// 누르는 순간 즉시 작아지고, 떼면 살짝 튕기며 돌아온다.
///
/// 감쇠를 0.55로 낮춰 복귀에 약간의 오버슛을 남겼다. 1에 가까우면 얌전하지만
/// 눌렀다는 느낌이 남지 않는다.
struct PressableStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.88
    /// 글자처럼 줄이면 어색한 대상은 밝기로만 반응시킨다.
    var pressedOpacity: Double = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// 누르면 그 곡을 Spotify에서 여는 제목. 마우스를 올리면 손가락 커서로 바뀐다.
struct LinkedTitle: View {
    let text: String
    let font: NSFont
    var color: Color = .primary
    let action: () -> Void

    @State private var hovering = false
    @State private var pushedCursor = false

    var body: some View {
        Button(action: action) {
            MarqueeText(text: text, font: font, color: color)
                .opacity(hovering ? 0.8 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(pressedScale: 1, pressedOpacity: 0.55))
        .help("Spotify에서 열기")
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.18)) { hovering = inside }
            setCursor(inside)
        }
        // 팝오버가 닫히면 onHover가 오지 않는다. 커서를 되돌려 놓지 않으면
        // 바깥에서도 손가락 모양이 남는다.
        .onDisappear { setCursor(false) }
    }

    private func setCursor(_ inside: Bool) {
        if inside, !pushedCursor {
            NSCursor.pointingHand.push()
            pushedCursor = true
        } else if !inside, pushedCursor {
            NSCursor.pop()
            pushedCursor = false
        }
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
    var spacing: CGFloat = 20

    var body: some View {
        HStack(spacing: spacing) {
            TransportButton(symbol: "backward.fill", size: 15, tint: tint, action: model.previousTrack)
            TransportButton(
                symbol: isPlaying ? "pause.fill" : "play.fill",
                size: 21,
                tint: tint,
                action: model.playPause
            )
            TransportButton(symbol: "forward.fill", size: 15, tint: tint, action: model.nextTrack)
        }
    }
}

extension TransportControls {
    /// 첫 버튼의 잉크가 프레임 왼쪽 끝에서 얼마나 들어가 있는지.
    ///
    /// 버튼은 누를 자리를 넓히려고 글리프보다 프레임이 크다. 글자와 같은 선에서
    /// 시작하게 하려면 이만큼 당겨야 한다. 눈대중으로 잡으면 어긋나고, 심볼
    /// 이미지의 크기로 잡아도 박스 안에 또 여백이 있어서 어긋난다. 실제로
    /// 칠해진 첫 열을 찾아서 쓴다.
    static let leadingGlyphInset: CGFloat = {
        let size: CGFloat = 15
        guard let image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: .medium)),
            let ink = image.leadingInk()
        else { return 0 }
        return (size * 2.1 - image.size.width) / 2 + ink
    }()
}

private extension NSImage {
    /// 이미지 왼쪽 끝에서 처음으로 칠해진 열까지의 거리(pt).
    func leadingInk() -> CGFloat? {
        let scale = 2
        let width = Int(size.width) * scale
        let height = Int(size.height) * scale
        guard width > 0, height > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.bindMemory(to: UInt8.self, capacity: width * height * 4) else {
            return nil
        }
        for x in 0..<width {
            for y in 0..<height where pixels[(y * width + x) * 4 + 3] > 8 {
                return CGFloat(x) / CGFloat(scale)
            }
        }
        return nil
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

// MARK: - 원형 커버

/// 초를 `mm:ss`로.
func clockText(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%02d:%02d", total / 60, total % 60)
}

/// 원으로 자른 커버와 그 둘레를 도는 진행 링.
///
/// 진행 바를 따로 두지 않고 커버 테두리가 그 역할을 한다. 링 위에서 끌면
/// 그 각도로 이동한다. 커버 안쪽에서 시작한 드래그는 무시해서, 위치를
/// 확인하려고 커버를 눌렀다가 곡이 튀는 일이 없게 한다.
struct RingArtwork: View {
    let image: NSImage?
    let diameter: CGFloat
    let position: Double
    let duration: Double
    let tint: Color
    var trackTint: Color = .white.opacity(0.28)
    let onScrub: (Double) -> Void
    let onCommit: (Double) -> Void

    /// 커버와 링 사이 간격.
    private let gap: CGFloat = 4
    private let baseRingWidth: CGFloat = 3
    private let hoverRingWidth: CGFloat = 5

    @State private var hovering = false
    @State private var dragging = false
    /// 12시를 넘나들 때 진행이 반대편으로 튀지 않도록 직전 값을 들고 있는다.
    @State private var lastFraction: Double = 0

    private var ringWidth: CGFloat { hovering || dragging ? hoverRingWidth : baseRingWidth }
    /// 스트로크의 중심선. 링은 이 선을 기준으로 안팎으로 같이 굵어진다.
    private var ringDiameter: CGFloat { diameter - hoverRingWidth }
    /// 가장 두꺼워진 링을 기준으로 잡아 두면 호버할 때 커버가 줄어들지 않는다.
    private var coverDiameter: CGFloat { ringDiameter - hoverRingWidth - 2 * gap }
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    /// 진행은 링이 보여 준다. 숫자는 실제로 탐색할 때만 필요하다.
    private var showsTime: Bool { hovering || dragging }

    var body: some View {
        ZStack {
            cover
            readout
            Circle()
                .stroke(trackTint, lineWidth: ringWidth)
                .frame(width: ringDiameter, height: ringDiameter)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ringDiameter, height: ringDiameter)
            knob
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(scrub)
        .animation(.easeOut(duration: 0.18), value: ringWidth)
        .smoothHover { hovering = $0 }
    }

    private var cover: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color.white.opacity(0.12).overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: coverDiameter * 0.26))
                        .foregroundStyle(.white.opacity(0.6))
                )
            }
        }
        .frame(width: coverDiameter, height: coverDiameter)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    }

    /// 만지는 동안 커버를 덮고 뜨는 시간. 위가 지금 위치, 아래가 곡 길이다.
    private var readout: some View {
        ZStack {
            Circle().fill(.black.opacity(0.45))
            VStack(spacing: 0) {
                Text(clockText(position))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                Text(clockText(duration))
                    .font(.system(size: 10).monospacedDigit())
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
        }
        .frame(width: coverDiameter, height: coverDiameter)
        .opacity(showsTime ? 1 : 0)
        .animation(.easeOut(duration: 0.18), value: showsTime)
    }

    /// 끌고 있는 동안에만 보이는 손잡이. 어디를 잡고 있는지 알려 준다.
    private var knob: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: ringWidth + 4, height: ringWidth + 4)
                .offset(y: -ringDiameter / 2)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(360 * progress))
        .opacity(hovering || dragging ? 1 : 0)
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !dragging {
                    guard isOnRing(value.startLocation) else { return }
                    dragging = true
                    lastFraction = progress
                }
                onScrub(seek(to: value.location))
            }
            .onEnded { value in
                guard dragging else { return }
                dragging = false
                onCommit(seek(to: value.location))
            }
    }

    private func isOnRing(_ point: CGPoint) -> Bool {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let distance = hypot(point.x - center.x, point.y - center.y)
        return distance >= coverDiameter / 2
    }

    private func seek(to point: CGPoint) -> Double {
        let center = diameter / 2
        var angle = atan2(point.x - center, center - point.y)
        if angle < 0 { angle += 2 * .pi }
        var next = angle / (2 * .pi)

        // 한 번에 반 바퀴 넘게 움직였다면 12시를 넘어간 것이다. 반대편으로
        // 튀는 대신 끝에 붙인다.
        if next - lastFraction > 0.5 {
            next = 0
        } else if lastFraction - next > 0.5 {
            next = 1
        }
        lastFraction = next
        return next * duration
    }
}
