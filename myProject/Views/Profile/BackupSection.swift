import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Файл копии для окна «Сохранить в…»: iCloud Drive, Google Drive, на iPhone — всё через «Файлы»
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Раздел настроек «Резервная копия»
struct BackupSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var includeMedia = false
    @State private var isPreparing = false
    @State private var document: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingRestore: BackupFile?
    @State private var message: String?

    var body: some View {
        Section(header: Text("Резервная копия"),
                footer: Text("Копия — один файл: сохраните его в iCloud Drive, Google Drive (если установлено приложение) или на iPhone. В копию входят прогресс слов, свои слова и словари, профиль, статистика, настройки и ваши темы. Картинки к словам загружаются заново сами.")) {
            Toggle("Включить книги и аудио", isOn: $includeMedia)

            Button {
                prepare()
            } label: {
                HStack {
                    Label("Создать копию", systemImage: "square.and.arrow.up")
                    Spacer()
                    if isPreparing { ProgressView() }
                }
            }
            .disabled(isPreparing)

            Button {
                isImporting = true
            } label: {
                Label("Восстановить из копии", systemImage: "arrow.counterclockwise")
            }
        }
        .fileExporter(isPresented: $isExporting, document: document, contentType: .json,
                      defaultFilename: Backup.fileName()) { result in
            if case .failure(let error) = result { message = error.localizedDescription }
            else { message = "Копия сохранена." }
            document = nil
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingRestore = try Backup.decode(Data(contentsOf: url))
            } catch {
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
        .alert("Восстановить из копии?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Восстановить", role: .destructive) { restore() }
        } message: {
            if let backup = pendingRestore {
                Text("Копия от \(backup.createdAt.formatted(date: .long, time: .shortened)): \(backup.summary).\n\nТекущий прогресс, словари и настройки заменятся данными из копии. На всякий случай они сохранятся в «Файлы» → «На iPhone» → папка приложения.")
            }
        }
        .alert("Резервная копия", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func prepare() {
        isPreparing = true
        // Данные собираются из базы на главном потоке, а большой файл кодируется в фоне
        let backup = Backup.make(context: modelContext, includeMedia: includeMedia)
        Task {
            defer { isPreparing = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) { try Backup.encode(backup) }.value
                document = BackupDocument(data: data)
                isExporting = true
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func restore() {
        guard let backup = pendingRestore else { return }
        pendingRestore = nil
        do {
            try Backup.restore(backup, context: modelContext)
            message = "Готово: \(backup.summary)."
        } catch {
            message = "Не получилось восстановить: \(error.localizedDescription). Данные не изменились."
        }
    }
}
