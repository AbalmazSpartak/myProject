import UIKit

/// Фото скана для словаря: уменьшенное до 1600 точек по длинной стороне, JPEG — примерно 300–500 КБ
enum ScanPhoto {
    private static let maxSide: CGFloat = 1600
    private static let quality: CGFloat = 0.7

    static func jpeg(from data: Data) -> Data? {
        UIImage(data: data).flatMap(jpeg(from:))
    }

    static func jpeg(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Поворот с камеры (imageOrientation) применяется при отрисовке — в JPEG уже правильная сторона
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
