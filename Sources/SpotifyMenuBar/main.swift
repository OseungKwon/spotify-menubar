import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let spotify = SpotifyController()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(spotify: spotify)
        spotify.start()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Dock 아이콘 없이 메뉴바에만 머문다.
app.setActivationPolicy(.accessory)
app.run()
