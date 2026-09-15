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
    var scale: CGFloat = 1
    var spacing: CGFloat = 20
    /// 주어진 폭 양끝에 붙이고 가운데 버튼을 한가운데 둔다.
    var justified: Bool = false

    var body: some View {
        HStack(spacing: justified ? 0 : spacing) {
            TransportButton(symbol: "backward.fill", size: 15 * scale, tint: tint, action: model.previousTrack)
            if justified { Spacer(minLength: 8) }
            TransportButton(
                symbol: isPlaying ? "pause.fill" : "play.fill",
                size: 21 * scale,
                tint: tint,
                action: model.playPause
            )
            if justified { Spacer(minLength: 8) }
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

// MARK: - 원형 커버

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
                Text(TimeLabels.clock(position))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                Text(TimeLabels.clock(duration))
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
