import UIKit
import ImageIO

/// Обложки книг: один раз уменьшаем до ~600 px и запоминаем, а не разбираем полный файл при каждой перерисовке
enum CoverCache {
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        return cache
    }()

    static let maxPixel = 600

    /// Ключ без хэширования всего файла: размер и первые байты
    private static func key(_ data: Data) -> NSString {
        "\(data.count)-\(data.prefix(64).hashValue)" as NSString
    }

    static func image(_ data: Data) -> UIImage? {
        let key = key(data)
        if let cached = cache.object(forKey: key) { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key)
        return image
    }
}
