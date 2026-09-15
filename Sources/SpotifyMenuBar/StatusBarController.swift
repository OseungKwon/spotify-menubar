import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// 메뉴바 아이템을 관리한다. 왼쪽 클릭은 재생 화면, 오른쪽 클릭은 설정 메뉴.
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: PlayerModel
    private let popover = NSPopover()
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

        buildPopover()
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
    }

    /// 뒤쪽을 잘라내고 말줄임표를 붙인다. 곡 제목이 앞에 오므로 앞부분을 지킨다.
    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        return text.prefix(max(limit - 1, 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - 팝오버

    private func buildPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = PopoverStyle.current.size
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = item.button else { return }
        model.spotify.refresh()
        // 열 때마다 새로 만든다. 이유는 popoverDidClose에 적어 뒀다.
        let style = PopoverStyle.current
        popover.contentSize = style.size
        popover.contentViewController = NSHostingController(rootView: NowPlayingView(model: model, style: style))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // accessory 앱이라 활성화해 주지 않으면 팝오버 안의 버튼이 첫 클릭을 놓친다.
        NSApp.activate(ignoringOtherApps: true)
        model.startTicking()
    }

    func popoverDidClose(_ notification: Notification) {
        model.stopTicking()
        // 마키와 재생 막대의 repeatForever 애니메이션은 팝오버가 닫혀도 계속 돈다.
        // 화면에 보이지도 않는 애니메이션이 CPU를 15%씩 먹어서, 뷰째로 버린다.
        popover.contentViewController = nil
    }

    // MARK: - 설정 메뉴

    private func buildMenu() {
        menu.autoenablesItems = false

        permissionItem.target = self
        menu.addItem(permissionItem)

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
            togglePopover()
        }
    }

    @objc private func openSpotify() { model.openSpotify() }

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
