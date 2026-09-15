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
        /// `spotify:track:...` 형태의 URI.
        var id: String
        var name: String
        var artist: String
        var album: String
        /// 초 단위. Spotify는 밀리초로 주므로 변환해서 담는다.
        var duration: Double
        var artworkURL: URL?
        var isPlaying: Bool
    }

    var track: Track? {
        if case .track(let track) = self { return track }
        return nil
    }
}

/// Spotify의 재생 상태를 추적한다.
///
/// 상태 변화는 Spotify가 쏘는 distributed notification으로 즉시 받고,
/// 알림이 오지 않는 변화는 타이머 폴링으로 메운다.
final class SpotifyController {
    static let bundleID = "com.spotify.client"
    private static let playbackChanged = Notification.Name("com.spotify.client.PlaybackStateChanged")
    /// 팝오버가 닫혀 있으면 재생 위치가 필요 없으므로 느리게 돈다.
    private static let idleInterval: TimeInterval = 5
    private static let liveInterval: TimeInterval = 1.5
    /// AppleScript 응답을 나누는 구분자. 곡 제목에 섞일 일이 없는 조합으로 고른다.
    private static let separator = "|~|"

    /// 상태가 실제로 바뀌었을 때만 메인 스레드에서 호출된다.
    var onChange: ((SpotifyState) -> Void)?
    private(set) var state: SpotifyState = .notRunning

    private let queue = DispatchQueue(label: "com.oseungkwon.spotifymenubar.applescript")
    private var timer: Timer?
    private var isLive = false

    /// 마지막으로 읽은 재생 위치와 그 시각. 둘을 묶어 두면 폴링 사이를 보간할 수 있다.
    private var sampledPosition: Double = 0
    private var sampledAt = Date()

    private let readScript = """
    tell application id "com.spotify.client"
        set d to "\(SpotifyController.separator)"
        set playerState to player state as text
        if playerState is "stopped" then return playerState
        set t to current track
        set art to ""
        try
            set art to artwork url of t
        end try
        return playerState & d & (id of t) & d & (name of t) & d & (artist of t) & d ¬
            & (album of t) & d & (duration of t as text) & d & art & d & (player position as text)
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
        scheduleTimer()
        refresh()
    }

    /// 팝오버가 열려 있는 동안에는 재생 위치를 자주 맞춘다.
    func setLive(_ live: Bool) {
        guard live != isLive else { return }
        isLive = live
        scheduleTimer()
        if live { refresh() }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(
            timeInterval: isLive ? Self.liveInterval : Self.idleInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refresh()
        }
        // 메뉴나 팝오버가 열려 있는 동안에도 갱신되도록 common 모드로 등록한다.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - 재생 위치

    /// 마지막 샘플에서 흐른 시간만큼 더한 현재 위치. 폴링 주기보다 부드럽게 움직인다.
    var position: Double {
        guard let track = state.track else { return 0 }
        guard track.isPlaying else { return sampledPosition }
        return min(sampledPosition + Date().timeIntervalSince(sampledAt), track.duration)
    }

    func seek(to seconds: Double) {
        guard let track = state.track else { return }
        let target = max(0, min(seconds, track.duration))
        samplePosition(target)
        run(command: "set player position to \(target)")
    }

    private func samplePosition(_ seconds: Double) {
        sampledPosition = seconds
        sampledAt = Date()
    }

    // MARK: - 읽기

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            let reading = self.read()
            DispatchQueue.main.async {
                if let position = reading.position { self.samplePosition(position) }
                self.apply(reading.state)
            }
        }
    }

    private func read() -> (state: SpotifyState, position: Double?) {
        guard isSpotifyRunning() else { return (.notRunning, nil) }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: readScript) else { return (.idle, nil) }
        let output = script.executeAndReturnError(&error)

        if let error {
            return (Self.isPermissionError(error) ? .needsPermission : .idle, nil)
        }
        guard let raw = output.stringValue else { return (.idle, nil) }

        let fields = raw.components(separatedBy: Self.separator)
        guard fields.count == 8 else { return (.idle, nil) }  // "stopped" 단독 응답
        let track = SpotifyState.Track(
            id: fields[1],
            name: fields[2],
            artist: fields[3],
            album: fields[4],
            duration: (Double(fields[5]) ?? 0) / 1000,
            artworkURL: URL(string: fields[6]),
            isPlaying: fields[0].caseInsensitiveCompare("playing") == .orderedSame
        )
        return (.track(track), Double(fields[7]))
    }

    /// 알림 payload만으로 상태를 만든다. AppleScript를 타지 않으므로 권한 없이도 동작한다.
    private func handlePlaybackNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }
        let playerState = info["Player State"] as? String ?? ""

        guard playerState.caseInsensitiveCompare("stopped") != .orderedSame,
              let id = info["Track ID"] as? String,
              let name = info["Name"] as? String else {
            apply(.idle)
            return
        }
        if let position = info["Playback Position"] as? Double { samplePosition(position) }

        // payload에는 아트워크 URL이 없다. 같은 곡이면 들고 있던 걸 쓰고,
        // 곡이 바뀌었으면 AppleScript로 한 번 더 물어본다.
        let previous = state.track
        let artworkURL = previous?.id == id ? previous?.artworkURL : nil

        apply(.track(SpotifyState.Track(
            id: id,
            name: name,
            artist: info["Artist"] as? String ?? "",
            album: info["Album"] as? String ?? "",
            duration: ((info["Duration"] as? Double) ?? 0) / 1000,
            artworkURL: artworkURL,
            isPlaying: playerState.caseInsensitiveCompare("playing") == .orderedSame
        )))
        if artworkURL == nil { refresh() }
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

    /// 재생 중인 곡을 Spotify에서 연다. id가 곧 `spotify:track:...` URI다.
    func openCurrentTrack() {
        guard let id = state.track?.id, let url = URL(string: id) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: -

    private func isSpotifyRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    /// -1743: 사용자가 자동화 권한을 거부함.
    private static func isPermissionError(_ error: NSDictionary) -> Bool {
        (error[NSAppleScript.errorNumber] as? Int) == -1743
    }
}
