import SwiftUI
import SwiftData
import PhotosUI

/// Словарь → скан текста: камера, фото, вставленный текст или файл → новые слова в свой словарь
struct TextScanView: View {
    /// Вызывается с созданным словарём, когда слова сохранены
    var onSaved: (WordList) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum Route: Hashable {
        case review, results
    }

    @State private var path: [Route] = []
    @State private var liveText = ""
    @State private var text = ""
    @State private var candidates: [ScanCandidate] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var isRecognizing = false
    @State private var progressMessage = "Распознаю текст…"
    @State private var errorMessage: String?
    @State private var isImportingFile = false
    /// Слова из файла: самые частые сверху, сразу отмечены, словарь запоминает частоту — учатся первыми
    @State private var fileName: String?
    @State private var fileNote: String?

    /// Сколько самых частых слов файла попадает в словарь
    static let maxFileWords = 5000

    var body: some View {
        NavigationStack(path: $path) {
            capture
                .navigationTitle("Слова из текста")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { dismiss() }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .review:
                        review
                    case .results:
                        ScanResultsView(candidates: candidates, fileName: fileName, note: fileNote) { list in
                            onSaved(list)
                            dismiss()
                        }
                    }
                }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await recognize(item) }
        }
        .alert("Не получилось", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Шаг 1: откуда взять текст

    private var capture: some View {
        VStack(spacing: 0) {
            ZStack {
                if LiveTextScanner.isAvailable {
                    LiveTextScanner(text: $liveText)
                        .ignoresSafeArea(edges: .horizontal)
                } else {
                    ContentUnavailableView(
                        "Камера недоступна",
                        systemImage: "camera.metering.unknown",
                        description: Text("Сканер текста работает только на iPhone с разрешённым доступом к камере. Выберите фото или вставьте текст.")
                    )
                }
                if isRecognizing {
                    ProgressView(progressMessage)
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            controls
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if LiveTextScanner.isAvailable {
                Button {
                    text = liveText
                    path.append(.review)
                } label: {
                    Label(liveText.isEmpty ? "Наведите камеру на текст" : "Снять текст", systemImage: "text.viewfinder")
                        .scaledFont(size: 17, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(liveText.isEmpty)
            }
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Фото", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button {
                    text = UIPasteboard.general.hasStrings ? (UIPasteboard.general.string ?? "") : ""
                    fileName = nil
                    path.append(.review)
                } label: {
                    Label("Вставить", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button {
                    isImportingFile = true
                } label: {
                    Label("Файл", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(isRecognizing)
        }
        .padding(16)
        .background(Color.brandBackground)
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: FileTextReader.allowedTypes) { result in
            if case .success(let url) = result {
                Task { await importFile(url) }
            }
        }
    }

    // MARK: - Файл

    /// Книга, статья, субтитры: читаем и разбираем в фоне, проверку текста пропускаем — сразу к словам
    private func importFile(_ url: URL) async {
        progressMessage = "Читаю файл…"
        isRecognizing = true
        defer { isRecognizing = false }

        let limit = Self.maxFileWords
        let parsed = await Task.detached(priority: .userInitiated) { () -> (FileTextReader.Result, [ExtractedWord])? in
            guard let file = try? FileTextReader.read(url) else { return nil }
            let found = TextWordExtractor.extract(from: file.text)
                .sorted { $0.count > $1.count }
            return (file, Array(found.prefix(limit)))
        }.value

        guard let (file, found) = parsed else {
            errorMessage = "Не получилось прочитать файл. Подходят .txt, субтитры .srt и .vtt, .pdf, .rtf, .html и книги .epub без защиты."
            return
        }
        guard !found.isEmpty else {
            errorMessage = "В файле не нашлось английских слов для изучения."
            return
        }
        var notes: [String] = []
        if file.isTruncated { notes.append("Файл очень большой — взято его начало.") }
        if found.count == Self.maxFileWords { notes.append("В словарь берутся \(Self.maxFileWords) самых частых слов файла.") }
        fileNote = notes.isEmpty ? nil : notes.joined(separator: " ")
        fileName = url.deletingPathExtension().lastPathComponent
        candidates = ScanMatcher.match(found, in: modelContext.fetchAllWords())
        path.append(.results)
    }

    private func recognize(_ item: PhotosPickerItem) async {
        progressMessage = "Распознаю текст…"
        fileName = nil
        isRecognizing = true
        defer {
            isRecognizing = false
            photoItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let recognized = try await PhotoTextRecognizer.text(in: data)
            guard !recognized.isEmpty else {
                errorMessage = "На фото не найден английский текст."
                return
            }
            text = recognized
            path.append(.review)
        } catch {
            errorMessage = "Не удалось распознать текст на фото."
        }
    }

    // MARK: - Шаг 2: проверить текст

    private var review: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.body)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            Text("Можно поправить ошибки распознавания и убрать лишнее.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.brandBackground)
        .navigationTitle("Текст")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Найти слова", action: findWords)
                    .bold()
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func findWords() {
        let found = TextWordExtractor.extract(from: text)
        guard !found.isEmpty else {
            // Английские слова могут быть, но только служебные — сканер их пропускает намеренно
            errorMessage = "Не нашлось слов для изучения. Сканер берёт существительные, глаголы, прилагательные и наречия, а служебные слова (the, is, this…) пропускает."
            return
        }
        fileName = nil
        fileNote = nil
        candidates = ScanMatcher.match(found, in: modelContext.fetchAllWords())
        path.append(.results)
    }
}
