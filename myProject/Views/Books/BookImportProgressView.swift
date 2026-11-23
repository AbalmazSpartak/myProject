import SwiftUI

/// Сколько страниц скана уже распознано (nil — обычное открытие книги без распознавания)
@Observable
final class BookImportProgress {
    private(set) var ocr: (page: Int, total: Int)?

    func update(page: Int, total: Int) { ocr = (page, total) }
    func reset() { ocr = nil }

    /// Для фоновой работы: безопасно сообщает о ходе на главный поток
    var report: PDFBook.Progress {
        { [self] page, total in Task { @MainActor in update(page: page, total: total) } }
    }
}

/// Плашка ожидания при добавлении книги: обычная, а у скана PDF — со строкой прогресса распознавания
struct BookImportProgressView: View {
    let progress: BookImportProgress

    var body: some View {
        VStack(spacing: 12) {
            if let ocr = progress.ocr {
                ProgressView(value: Double(ocr.page), total: Double(max(ocr.total, 1)))
                Text("Распознаю текст: страница \(min(ocr.page + 1, ocr.total)) из \(ocr.total)")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Это скан, поэтому дольше обычного")
                    .font(.footnote)
                    .foregroundStyle(Color.brandMuted)
            } else {
                ProgressView("Открываю книгу…")
            }
        }
        .multilineTextAlignment(.center)
        .padding(20)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
