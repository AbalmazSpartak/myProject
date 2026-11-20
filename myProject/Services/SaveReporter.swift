import SwiftUI
import SwiftData
import OSLog

/// Ошибка сохранения, о которой надо сказать человеку: раньше `try? save()` проглатывал её, и правка пропадала молча
@MainActor
@Observable
final class SaveIssue {
    static let shared = SaveIssue()
    /// Текст для окна; nil — всё в порядке. Пока окно не закрыто, новые ошибки его не заменяют
    var message: String?

    private let log = Logger(subsystem: "com.personalteam.lexistream", category: "save")

    func report(_ error: Error) {
        log.error("Сохранение не удалось: \(String(describing: error), privacy: .public)")
        guard message == nil else { return }
        message = "Не удалось сохранить последние изменения. Возможно, на iPhone кончилось место. Освободите память и повторите действие; если окно появится снова, закройте и откройте приложение."
    }
}

extension ModelContext {
    /// Сохраняет и, если не вышло, показывает окно с объяснением (вместо молчаливого `try?`)
    func saveReporting() {
        do {
            try save()
        } catch {
            SaveIssue.shared.report(error)
        }
    }
}

/// Экран вместо падения, когда база не открылась: данные не трогаем, даём сохранить копию и показываем причину
struct StartupFailureView: View {
    let error: String

    /// Файлы базы, которые существуют, — их можно отправить разработчику или сохранить в «Файлы»
    private var storeFiles: [URL] {
        let base = MyApp.storeURL()
        let folder = base.deletingLastPathComponent()
        let name = base.lastPathComponent
        return [name, name + "-wal", name + "-shm"]
            .map { folder.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .scaledFont(size: 44)
                    .foregroundStyle(Color.statusLearning)
                Text("Не удалось открыть данные")
                    .scaledFont(size: 30, weight: .semibold, design: .serif)
                    .foregroundStyle(Color.brandDark)
                Text("Слова и книги не удалены: приложение их не трогало. Закройте LexiStream полностью и откройте снова. Если экран появится опять, сохраните копию данных ниже и пришлите её разработчику. Не удаляйте приложение, пока копия не сохранена.")
                    .scaledFont(size: 15)
                    .foregroundStyle(Color.brandMuted)
                if !storeFiles.isEmpty {
                    ShareLink(items: storeFiles) {
                        Label("Сохранить копию данных", systemImage: "square.and.arrow.up")
                            .scaledFont(size: 16, weight: .semibold)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(Color.white)
                            .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                Text("Причина")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(Color.brandMuted)
                    .padding(.top, 8)
                Text(error)
                    .scaledFont(size: 12)
                    .foregroundStyle(Color.brandMuted)
                    .textSelection(.enabled)
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }
}
