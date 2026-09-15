import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// 메뉴바 아이템을 관리한다. 왼쪽 클릭은 재생 화면, 오른쪽 클릭은 설정 메뉴.
final class StatusBarController: NSObject, NSWindowDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: PlayerModel
    private var panel: PlayerPanel?
    private var outsideClickMonitor: Any?
    /// 바깥 클릭으로 막 닫힌 직후의 메뉴바 클릭을 걸러내는 시각.
    private var closedAt = Date.distantPast
    private let menu = NSMenu()
    private let lengthMenu = NSMenu()
    private let styleMenu = NSMenu()
    private let launchAtLoginItem = NSMenuItem(
        title: "로그인 시 자동 실행", action: #selector(toggleLaunchAtLogin), keyEquivalent: ""
    )
    private lazy var permissionItem = NSMenuItem(
        title: "자동화 권한 열기…", action: #selector(openAutomationSettings), keyEquivalent: ""
    )
    private var cancellables = Set<AnyCancellable>()

    /// 메뉴바를 독점하지 않도록 제목을 이 길이에서 자른다.
    private var maxTitleLength: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "maxTitleLength")
            return Self.lengthOptions.contains(stored) ? stored : 40
        }
        set { UserDefaults.standard.set(newValue, forKey: "maxTitleLength") }
    }
    private static let lengthOptions = [20, 30, 40, 60]

    init(model: PlayerModel) {
        self.model = model
        super.init()

        buildMenu()
        buildStatusItem()
        render(state: model.state)

        model.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.render(state: state) }
            .store(in: &cancellables)
    }

    // MARK: - 메뉴바 아이템

    private func buildStatusItem() {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        // 오른쪽 버튼까지 받아야 설정 메뉴를 띄울 수 있다.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func render(state: SpotifyState) {
        switch state {
        case .track(let track):
            let label = track.artist.isEmpty ? track.name : "\(track.name) - \(track.artist)"
            // 아이콘이 없으니 재생 중인지 여부는 글자 밝기로만 드러난다.
            setTitle(Self.truncate(label, to: maxTitleLength), dimmed: !track.isPlaying)

        case .idle, .notRunning:
            // 제목을 비우면 누를 자리가 사라진다. 앱 이름만 흐리게 남긴다.
            setTitle("Spotify", dimmed: true)

        case .needsPermission:
            setTitle("권한 필요", dimmed: false)
        }

        permissionItem.isHidden = state != .needsPermission
    }

    private func setTitle(_ text: String, dimmed: Bool) {
        guard let button = item.button else { return }
        button.image = nil
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: dimmed ? NSColor.secondaryLabelColor : NSColor.labelColor]
        )
        // 제목을 바꾸면 눌린 표시가 풀린다. 재생 화면이 떠 있는 동안에는 되살린다.
        if panel?.isVisible == true { button.highlight(true) }
    }

    /// 뒤쪽을 잘라내고 말줄임표를 붙인다. 곡 제목이 앞에 오므로 앞부분을 지킨다.
    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        return text.prefix(max(limit - 1, 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - 재생 화면

    private func togglePanel() {
        if panel?.isVisible == true {
            closePanel()
            return
        }
        // 바깥 클릭으로 방금 닫혔는데 그 클릭이 메뉴바 아이템이었다면,
        // 여기서 다시 열려 깜빡인다.
        guard Date().timeIntervalSince(closedAt) > 0.2 else { return }
        openPanel()
    }

    private func openPanel() {
        guard let button = item.button else { return }
        model.spotify.refresh()

        let style = PopoverStyle.current
        let panel = PlayerPanel(size: style.size)
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: NowPlayingView(model: model, style: style).cornerClipped()
        )
        panel.position(below: button)
        panel.orderFront(nil)
        panel.makeKey()
        self.panel = panel

        // 다른 앱 위를 클릭하면 닫는다. 메뉴바 아이템은 우리 앱이라 여기 걸리지 않는다.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePanel()
        }

        // 다른 메뉴바 앱처럼 화면이 떠 있는 동안 아이템을 눌린 상태로 둔다.
        button.highlight(true)
        model.startTicking()
    }

    private func closePanel() {
        guard let panel, panel.isVisible else { return }
        panel.delegate = nil
        panel.orderOut(nil)
        // 마키의 repeatForever 애니메이션은 창이 숨어도 계속 돈다. 보이지도 않는
        // 애니메이션이 CPU를 15%씩 먹어서, 뷰째로 버린다.
        panel.contentView = NSView()
        self.panel = nil

        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        item.button?.highlight(false)
        model.stopTicking()
        closedAt = Date()
    }

    /// 다른 앱으로 포커스가 넘어가면 닫는다.
    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }

    // MARK: - 설정 메뉴

    private func buildMenu() {
        menu.autoenablesItems = false

        permissionItem.target = self
        menu.addItem(permissionItem)

        let openTrackItem = NSMenuItem(
            title: "이 곡 Spotify에서 열기", action: #selector(openTrack), keyEquivalent: ""
        )
        openTrackItem.target = self
        menu.addItem(openTrackItem)

        let openItem = NSMenuItem(title: "Spotify 열기", action: #selector(openSpotify), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let styleItem = NSMenuItem(title: "재생 화면 디자인", action: nil, keyEquivalent: "")
        for style in PopoverStyle.allCases {
            let entry = NSMenuItem(title: style.title, action: #selector(selectStyle(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = style.rawValue
            styleMenu.addItem(entry)
        }
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)

        let lengthItem = NSMenuItem(title: "메뉴바 표시 길이", action: nil, keyEquivalent: "")
        for option in Self.lengthOptions {
            let entry = NSMenuItem(title: "\(option)자", action: #selector(selectLength(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = option
            lengthMenu.addItem(entry)
        }
        lengthItem.submenu = lengthMenu
        menu.addItem(lengthItem)

        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private func showMenu() {
        guard let button = item.button else { return }
        for entry in lengthMenu.items {
            entry.state = entry.tag == maxTitleLength ? .on : .off
        }
        for entry in styleMenu.items {
            entry.state = (entry.representedObject as? String) == PopoverStyle.current.rawValue ? .on : .off
        }
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    // MARK: - 액션

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            showMenu()
        } else {
            togglePanel()
        }
    }

    @objc private func openSpotify() { model.openSpotify() }

    @objc private func openTrack() { model.openTrackInSpotify() }

    @objc private func selectStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = PopoverStyle(rawValue: raw) else { return }
        PopoverStyle.current = style
        // 팝오버는 열릴 때 새로 만들어지므로 다음에 열면 바뀐 디자인이 나온다.
    }

    @objc private func selectLength(_ sender: NSMenuItem) {
        maxTitleLength = sender.tag
        render(state: model.state)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "자동 실행 설정을 바꾸지 못했습니다"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
}
