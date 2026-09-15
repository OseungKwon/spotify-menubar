import AppKit
import SwiftUI

/// 재생 화면을 담는 창.
///
/// NSPopover는 말풍선 부리를 항상 그리고 그 모양을 끌 수 없다. 메뉴바 아래에
/// 그냥 붙는 판을 만들려면 테두리 없는 패널을 직접 띄워야 한다.
final class PlayerPanel: NSPanel {
    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            // nonactivatingPanel이라야 앞에 있던 앱의 포커스를 뺏지 않는다.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// 테두리 없는 창은 기본적으로 키가 되지 못한다. 키가 되어야 바깥을
    /// 클릭했을 때 닫을 시점을 알 수 있다.
    override var canBecomeKey: Bool { true }

    /// 메뉴바 아이템 바로 아래, 버튼 가운데에 맞춰 세운다.
    func position(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let onScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))

        var origin = NSPoint(
            x: onScreen.midX - frame.width / 2,
            y: onScreen.minY - frame.height - 4
        )
        // 메뉴바 끝에 있는 아이템이면 화면 밖으로 나간다.
        if let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
        }
        setFrameOrigin(origin)
    }
}

extension View {
    /// 테두리 없는 창에는 모서리가 없다. 내용 쪽에서 둥글게 잘라 준다.
    func cornerClipped() -> some View {
        clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
