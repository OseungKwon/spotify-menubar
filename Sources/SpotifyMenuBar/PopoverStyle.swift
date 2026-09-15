import Foundation

/// 재생 화면의 생김새. 오른쪽 클릭 메뉴에서 바꾼다.
enum PopoverStyle: String, CaseIterable {
    /// 커버를 크게 블러해 배경으로 깔고 그 위에 올린다.
    case coverBleed
    /// 커버를 상단 전면에 세운 포스터.
    case poster
    /// 한 줄로 눕힌 얇은 띠.
    case strip

    var title: String {
        switch self {
        case .coverBleed: return "커버가 번지는 배경"
        case .poster: return "포스터"
        case .strip: return "얇은 스트립"
        }
    }

    var size: CGSize {
        switch self {
        case .coverBleed: return CGSize(width: 372, height: 154)
        case .poster: return CGSize(width: 320, height: 300)
        case .strip: return CGSize(width: 380, height: 86)
        }
    }

    private static let key = "popoverStyle"

    static var current: PopoverStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key) else { return .coverBleed }
            return PopoverStyle(rawValue: raw) ?? .coverBleed
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
