import AppKit

/// Spotify 데스크톱 앱에서 읽어온 현재 재생 상태.
enum SpotifyState: Equatable {
    /// Spotify가 실행 중이 아님.
    case notRunning
    /// 실행 중이지만 재생 중인 트랙이 없음.
    case idle
    /// 자동화(Apple Events) 권한이 거부됨.
    case needsPermission
    case track(Track)

    struct Track: Equatable {
        var name: String
        var artist: String
        var isPlaying: Bool
    }
}

/// Spotify의 재생 상태를 추적한다.
///
/// 상태 변화는 Spotify가 쏘는 distributed notification으로 즉시 받고,
/// 앱 종료/실행처럼 알림이 오지 않는 변화는 타이머 폴링으로 메운다.
final class SpotifyController {
    static let bundleID = "com.spotify.client"
    private static let playbackChanged = Notification.Name("com.spotify.client.PlaybackStateChanged")
    private static let pollInterval: TimeInterval = 5

    /// 상태가 실제로 바뀌었을 때만 메인 스레드에서 호출된다.
    var onChange: ((SpotifyState) -> Void)?
    private(set) var state: SpotifyState = .notRunning

    private let queue = DispatchQueue(label: "com.oseungkwon.spotifymenubar.applescript")
    private var timer: Timer?

    private let readScript = """
    tell application id "com.spotify.client"
        set playerState to player state as text
        if playerState is "stopped" then return playerState
        return playerState & tab & (name of current track) & tab & (artist of current track)
    end tell
    """

    func start() {
        DistributedNotificationCenter.default().addObserver(
            forName: Self.playbackChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handlePlaybackNotification(note)
        }

        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // 메뉴를 열어둔 동안에도 갱신되도록 common 모드로 등록한다.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        refresh()
    }

    // MARK: - 읽기

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            let next = self.read()
            DispatchQueue.main.async { self.apply(next) }
        }
    }

    private func read() -> SpotifyState {
        guard isSpotifyRunning() else { return .notRunning }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: readScript) else { return .idle }
        let output = script.executeAndReturnError(&error)

        if let error {
            return Self.isPermissionError(error) ? .needsPermission : .idle
        }
        guard let raw = output.stringValue else { return .idle }

        let fields = raw.components(separatedBy: "\t")
        guard fields.count == 3 else { return .idle }  // "stopped" 단독 응답
        return .track(SpotifyState.Track(
            name: fields[1],
            artist: fields[2],
            isPlaying: fields[0].caseInsensitiveCompare("playing") == .orderedSame
        ))
    }

    /// 알림 payload만으로 상태를 만든다. AppleScript를 타지 않으므로 권한 없이도 동작한다.
    private func handlePlaybackNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }
        let playerState = info["Player State"] as? String ?? ""

        guard playerState.caseInsensitiveCompare("stopped") != .orderedSame,
              let name = info["Name"] as? String else {
            apply(.idle)
            return
        }
        apply(.track(SpotifyState.Track(
            name: name,
            artist: info["Artist"] as? String ?? "",
            isPlaying: playerState.caseInsensitiveCompare("playing") == .orderedSame
        )))
    }

    private func apply(_ next: SpotifyState) {
        guard next != state else { return }
        state = next
        onChange?(next)
    }

    // MARK: - 제어

    func playPause() { run(command: "playpause") }
    func nextTrack() { run(command: "next track") }
    func previousTrack() { run(command: "previous track") }

    private func run(command: String) {
        guard isSpotifyRunning() else { return }
        queue.async { [weak self] in
            guard let self else { return }
            var error: NSDictionary?
            NSAppleScript(source: "tell application id \"\(Self.bundleID)\" to \(command)")?
                .executeAndReturnError(&error)
            if let error, Self.isPermissionError(error) {
                DispatchQueue.main.async { self.apply(.needsPermission) }
                return
            }
            // 명령 직후 Spotify가 보내는 알림이 없을 수도 있어 한 번 더 읽는다.
            self.refresh()
        }
    }

    /// Spotify 창을 앞으로 가져온다. 꺼져 있으면 실행한다.
    func activateSpotify() {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first {
            running.activate(options: [.activateAllWindows])
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: -

    private func isSpotifyRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    /// -1743: 사용자가 자동화 권한을 거부함. -600: 대상 앱이 막 종료됨.
    private static func isPermissionError(_ error: NSDictionary) -> Bool {
        (error[NSAppleScript.errorNumber] as? Int) == -1743
    }
}
