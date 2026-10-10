import SwiftUI
import VisionKit

/// Камера с подсветкой распознанного текста (как «Текст с камеры» в Заметках).
/// В `text` — весь видимый сейчас текст, строки сверху вниз.
struct LiveTextScanner: UIViewControllerRepresentable {
    @Binding var text: String
    /// Через него экран скана снимает кадр — фото сохранится в словаре
    var handle: Handle

    /// Доступ к камере сканера извне SwiftUI
    final class Handle {
        fileprivate weak var scanner: DataScannerViewController?

        /// Кадр с камеры в момент «Снять текст»; nil — камера не дала снимок
        func capturePhoto() async -> UIImage? {
            try? await scanner?.capturePhoto()
        }
    }

    /// Нет на симуляторе и на старых устройствах; ещё может быть запрещён доступ к камере
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["en"])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        handle.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            update(with: allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            update(with: allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            update(with: allItems)
        }

        /// Блоки текста в порядке чтения: сверху вниз, в строке — слева направо
        private func update(with items: [RecognizedItem]) {
            let lines: [(y: CGFloat, x: CGFloat, text: String)] = items.compactMap { item in
                guard case .text(let recognized) = item else { return nil }
                return (recognized.bounds.topLeft.y, recognized.bounds.topLeft.x, recognized.transcript)
            }
            text.wrappedValue = lines
                .sorted { abs($0.y - $1.y) < 8 ? $0.x < $1.x : $0.y < $1.y }
                .map(\.text)
                .joined(separator: "\n")
        }
    }
}
