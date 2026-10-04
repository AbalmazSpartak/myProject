import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

/// «Таблица по фото»: камера, фото или картинка из «Файлов» → распознанная таблица в редакторе
struct TablePhotoImportButton: View {
    @Binding var table: TopicTable

    @State private var isShowingCamera = false
    @State private var isShowingPhotos = false
    @State private var isShowingFiles = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isRecognizing = false
    /// Распознанная таблица ждёт подтверждения замены — в редакторе уже что-то есть
    @State private var pending: RecognizedTable?
    @State private var message: String?

    var body: some View {
        Menu {
            if VNDocumentCameraViewController.isSupported {
                Button { isShowingCamera = true } label: {
                    Label("Сфотографировать", systemImage: "camera")
                }
            }
            Button { isShowingPhotos = true } label: {
                Label("Выбрать из фото", systemImage: "photo.on.rectangle")
            }
            Button { isShowingFiles = true } label: {
                Label("Картинка из «Файлов»", systemImage: "folder")
            }
        } label: {
            HStack {
                Label("Таблица по фото", systemImage: "camera.viewfinder")
                Spacer()
                if isRecognizing {
                    ProgressView()
                    Text("Распознаю…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(isRecognizing)
        .fullScreenCover(isPresented: $isShowingCamera) {
            DocumentCamera { image in
                isShowingCamera = false
                if let image { recognize(image) }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $isShowingPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    recognize(image)
                } else {
                    message = "Не получилось открыть фото."
                }
            }
        }
        .fileImporter(isPresented: $isShowingFiles, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                recognize(image)
            } else {
                message = "Не получилось открыть картинку."
            }
        }
        .alert("Заменить таблицу?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Заменить", role: .destructive) {
                if let pending { apply(pending) }
            }
        } message: {
            Text("То, что уже есть в таблице, заменится распознанным с фото.")
        }
        .alert("Таблица по фото", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func recognize(_ image: UIImage) {
        isRecognizing = true
        let maxRows = TopicTable.rowRange.upperBound, maxColumns = TopicTable.columnRange.upperBound
        Task {
            defer { isRecognizing = false }
            do {
                let recognized = try await Task.detached(priority: .userInitiated) {
                    try await TableRecognizer.recognize(image, maxRows: maxRows, maxColumns: maxColumns)
                }.value
                if table.isEmpty {
                    apply(recognized)
                } else {
                    pending = recognized
                }
            } catch {
                message = "Не нашлось текста. Сфотографируйте таблицу ровнее и ближе, при хорошем свете."
            }
        }
    }

    private func apply(_ recognized: RecognizedTable) {
        var result = TopicTable()
        result.cells = recognized.cells
        result.hasHeaderRow = true
        result.hasHeaderColumn = Self.hasLabelsColumn(recognized)
        for span in recognized.spans {
            var style = result.style(row: span.row, column: span.column)
            style.rowSpan = span.rowSpan
            style.columnSpan = span.columnSpan
            result.setStyle(style, row: span.row, column: span.column)
        }
        for (key, tone) in recognized.tones {
            let position = key.split(separator: ":").compactMap { Int($0) }
            guard position.count == 2 else { continue }
            var style = result.style(row: position[0], column: position[1])
            style.tone = tone == .red ? .red : .gray
            result.setStyle(style, row: position[0], column: position[1])
        }
        table = result
        message = (recognized.wasTrimmed
            ? "Таблица больше, чем \(TopicTable.rowRange.upperBound) строк или \(TopicTable.columnRange.upperBound) столбцов, — лишнее не вошло. "
            : "")
            + "Проверьте текст и оформление: курсив, вертикальные подписи и деление ячеек на столбцы с фото не переносятся."
    }

    /// Столбец подписей («Past / Present / Future»): слева пусто в строке шапки, а в остальных строках подписи есть
    private static func hasLabelsColumn(_ table: RecognizedTable) -> Bool {
        guard table.columns > 1 else { return false }
        let coveredFirstColumn = Set(table.spans.filter { $0.column == 0 && $0.columnSpan > 1 }.map(\.row))
        let rows = (0..<table.rows).filter { !coveredFirstColumn.contains($0) }
        let emptyLabel = rows.filter { row in
            table.cells[row][0].isEmpty && table.cells[row].dropFirst().contains { !$0.isEmpty }
        }
        let filledLabel = rows.filter { !table.cells[$0][0].isEmpty }
        return emptyLabel.count == 1 && filledLabel.count >= 2
    }
}

/// Камера «Документы» iOS: сама находит лист, выравнивает перспективу и убирает тени
private struct DocumentCamera: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ camera: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Снято несколько листов — берём первый
            onFinish(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish(nil)
        }
    }
}
