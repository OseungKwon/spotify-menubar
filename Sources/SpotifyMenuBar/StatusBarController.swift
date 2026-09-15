import AppKit
import ServiceManagement

/// 메뉴바 아이템의 제목과 메뉴를 관리한다.
final class StatusBarController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let spotify: SpotifyController
    private let titleItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let playPauseItem = NSMenuItem(title: "재생", action: #selector(playPause), keyEquivalent: "")
    private let lengthMenu = NSMenu()
    private let launchAtLoginItem = NSMenuItem(
        title: "로그인 시 자동 실행", action: #selector(toggleLaunchAtLogin), keyEquivalent: ""
    )

    /// 메뉴바를 독점하지 않도록 제목을 이 길이에서 자른다.
    private var maxTitleLength: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "maxTitleLength")
            return Self.lengthOptions.contains(stored) ? stored : 40
        }
        set { UserDefaults.standard.set(newValue, forKey: "maxTitleLength") }
    }
    private static let lengthOptions = [20, 30, 40, 60]

    init(spotify: SpotifyController) {
        self.spotify = spotify
        buildMenu()
        render(state: spotify.state)
        spotify.onChange = { [weak self] state in self?.render(state: state) }
    }

    // MARK: - 렌더링

    private func render(state: SpotifyState) {
        guard let button = item.button else { return }

        switch state {
        case .track(let track):
            let label = track.artist.isEmpty ? track.name : "\(track.name) - \(track.artist)"
            button.title = Self.truncate(label, to: maxTitleLength)
            button.image = symbol(track.isPlaying ? "music.note" : "pause.fill")
            titleItem.title = label
            titleItem.isHidden = false
            playPauseItem.title = track.isPlaying ? "일시정지" : "재생"
            playPauseItem.isEnabled = true

        case .idle:
            button.title = ""
            button.image = symbol("music.note")
            titleItem.isHidden = true
            playPauseItem.title = "재생"
            playPauseItem.isEnabled = true

        case .notRunning:
            button.title = ""
            button.image = symbol("music.note")
            titleItem.isHidden = true
            playPauseItem.title = "재생"
            playPauseItem.isEnabled = false

        case .needsPermission:
            button.title = "권한 필요"
            button.image = symbol("exclamationmark.triangle")
            titleItem.title = "Spotify 제어 권한이 필요합니다"
            titleItem.isHidden = false
            playPauseItem.isEnabled = false
        }

        permissionItem.isHidden = state != .needsPermission
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    /// 뒤쪽을 잘라내고 말줄임표를 붙인다. 곡 제목이 앞에 오므로 앞부분을 지킨다.
    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        return text.prefix(max(limit - 1, 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - 메뉴

    private lazy var permissionItem = NSMenuItem(
        title: "자동화 권한 열기…", action: #selector(openAutomationSettings), keyEquivalent: ""
    )

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        titleItem.isEnabled = false
        menu.addItem(titleItem)

        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())

        playPauseItem.target = self
        menu.addItem(playPauseItem)
        for (title, action) in [("이전 곡", #selector(previousTrack)), ("다음 곡", #selector(nextTrack))] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Spotify 열기", action: #selector(openSpotify), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let lengthItem = NSMenuItem(title: "표시 길이", action: nil, keyEquivalent: "")
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

        menu.delegate = menuDelegate
        item.menu = menu
    }

    /// 메뉴를 열 때마다 최신 상태와 체크 표시를 맞춘다.
    private lazy var menuDelegate = MenuDelegate { [weak self] in
        guard let self else { return }
        self.spotify.refresh()
        for entry in self.lengthMenu.items {
            entry.state = entry.tag == self.maxTitleLength ? .on : .off
        }
        self.launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - 액션

    @objc private func playPause() { spotify.playPause() }
    @objc private func nextTrack() { spotify.nextTrack() }
    @objc private func previousTrack() { spotify.previousTrack() }
    @objc private func openSpotify() { spotify.activateSpotify() }

    @objc private func selectLength(_ sender: NSMenuItem) {
        maxTitleLength = sender.tag
        render(state: spotify.state)
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

/// 메뉴가 열리는 순간을 알려주는 얇은 델리게이트.
private final class MenuDelegate: NSObject, NSMenuDelegate {
    private let willOpen: () -> Void
    init(willOpen: @escaping () -> Void) { self.willOpen = willOpen }
    func menuWillOpen(_ menu: NSMenu) { willOpen() }
}
