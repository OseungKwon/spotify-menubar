import AppKit
import SwiftUI

/// 폭을 넘치는 텍스트를 옆으로 흘려 보여 준다. 들어가는 텍스트는 그냥 멈춰 있는다.
struct MarqueeText: View {
    let text: String
    let font: NSFont
    var color: Color = .primary

    /// 같은 문구가 한 바퀴 돌아올 때까지의 간격.
    private let gap: CGFloat = 36
    private let speed: CGFloat = 26  // pt/s
    /// 한 바퀴 돌 때마다 제목 앞부분을 이만큼 세워 둔다. 바로 흐르면 읽을 틈이 없다.
    private let pause: Double = 1.8

    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var textWidth: CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
    private var overflows: Bool { textWidth > containerWidth + 0.5 }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: gap) {
                label
                if overflows { label }
            }
            .offset(x: offset)
            .frame(width: geometry.size.width, alignment: .leading)
            .clipped()
            .mask(fade)
            .onAppear {
                containerWidth = geometry.size.width
                restart()
            }
            .onChange(of: geometry.size.width) { width in
                containerWidth = width
                restart()
            }
            .onChange(of: text) { _ in restart() }
        }
        .frame(height: ceil(font.boundingRectForFont.height))
    }

    private var label: some View {
        Text(text)
            .font(Font(font))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    /// 글자가 잘리는 오른쪽 끝만 흐리게 해서 딱 끊기지 않게 한다.
    private var fade: some View {
        LinearGradient(
            stops: overflows
                ? [.init(color: .black, location: 0.88), .init(color: .clear, location: 1)]
                : [.init(color: .black, location: 1)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func restart() {
        offset = 0
        guard overflows else { return }
        let distance = textWidth + gap
        // 두 번째 사본이 첫 사본 자리에 정확히 겹치는 지점에서 끝나므로, 되감아도 티가 나지 않는다.
        let scroll = Animation.linear(duration: Double(distance / speed)).delay(pause)
        withAnimation(scroll.repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}
