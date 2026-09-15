import AppKit

/// 앨범 커버를 받아 오고, 배경에 쓸 대표색을 뽑는다.
enum Artwork {
    private static let cache = NSCache<NSURL, NSImage>()
    private static let colorCache = NSCache<NSURL, NSColor>()

    /// 이미 받아 둔 커버가 있으면 즉시 돌려준다. 곡이 바뀌는 순간 깜빡이지 않게 한다.
    static func cached(_ url: URL) -> (image: NSImage, accent: NSColor)? {
        guard let image = cache.object(forKey: url as NSURL) else { return nil }
        return (image, colorCache.object(forKey: url as NSURL) ?? .controlAccentColor)
    }

    static func load(_ url: URL, completion: @escaping (NSImage, NSColor) -> Void) {
        if let hit = cached(url) {
            completion(hit.image, hit.accent)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            let accent = dominantColor(of: image) ?? .controlAccentColor
            cache.setObject(image, forKey: url as NSURL)
            colorCache.setObject(accent, forKey: url as NSURL)
            DispatchQueue.main.async { completion(image, accent) }
        }.resume()
    }

    /// 커버를 32x32로 줄인 뒤 가장 선명한 픽셀을 고른다.
    ///
    /// 평균색은 대부분 흙빛 회색으로 수렴해서 배경으로 쓸 수 없다.
    /// 채도와 밝기가 함께 높은 픽셀을 뽑아야 앨범의 인상이 남는다.
    private static func dominantColor(of image: NSImage) -> NSColor? {
        let side = 32
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let pixels = context.data?.bindMemory(to: UInt8.self, capacity: side * side * 4) else { return nil }

        var best: (score: CGFloat, color: NSColor)?
        for index in stride(from: 0, to: side * side * 4, by: 4) {
            let color = NSColor(
                red: CGFloat(pixels[index]) / 255,
                green: CGFloat(pixels[index + 1]) / 255,
                blue: CGFloat(pixels[index + 2]) / 255,
                alpha: 1
            )
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            let score = saturation * (0.35 + brightness * 0.65)
            if score > (best?.score ?? 0) { best = (score, color) }
        }

        // 흑백 커버는 뽑을 색이 없다. 이럴 땐 시스템 강조색에 맡긴다.
        guard let winner = best, winner.score > 0.08 else { return nil }

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        winner.color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        // 너무 쨍하거나 어두우면 배경으로 깔았을 때 글자가 묻힌다.
        return NSColor(
            hue: hue,
            saturation: min(saturation, 0.75),
            brightness: max(min(brightness, 0.85), 0.45),
            alpha: 1
        )
    }
}
