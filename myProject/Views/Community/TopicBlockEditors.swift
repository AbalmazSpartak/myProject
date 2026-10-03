import SwiftUI
import UniformTypeIdentifiers

/// Звук, записанный или выбранный в редакторе, — до сохранения темы
struct PendingAudio {
    let data: Data
    let fileExtension: String
}

// MARK: - Таблица

struct TopicTableEditor: View {
    @Binding var table: TopicTable

    var body: some View {
        Stepper("Строк: \(table.rows)", value: Binding(
            get: { table.rows },
            set: { table.resize(rows: $0, columns: table.columns) }
        ), in: TopicTable.rowRange)
        Stepper("Столбцов: \(table.columns)", value: Binding(
            get: { table.columns },
            set: { table.resize(rows: table.rows, columns: $0) }
        ), in: TopicTable.columnRange)
        Toggle("Первая строка — шапка", isOn: $table.hasHeaderRow)
        Toggle("Первый столбец — подписи", isOn: $table.hasHeaderColumn)

        ScrollView(.horizontal, showsIndicators: false) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<table.rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<table.columns, id: \.self) { column in
                            cellField(row: row, column: column)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func cellField(row: Int, column: Int) -> some View {
        let isHeader = (table.hasHeaderRow && row == 0) || (table.hasHeaderColumn && column == 0)
        // В ячейке может быть несколько строк: «I / you / we / they» — каждое с новой строки
        return TextField("", text: Binding(
            get: { row < table.rows && column < table.columns ? table.cells[row][column] : "" },
            set: { if row < table.rows && column < table.columns { table.cells[row][column] = $0 } }
        ), axis: .vertical)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(isHeader ? .body.weight(.semibold) : .body)
        .padding(6)
        .frame(width: 120, alignment: .topLeading)
        .background(isHeader ? Color.brandAccent.opacity(0.6) : Color.brandInputBg)
        .cornerRadius(6)
    }
}

// MARK: - Аудио

struct TopicAudioEditor: View {
    @Binding var block: TopicBlock
    @Binding var pendingAudio: [UUID: PendingAudio]

    @State private var recorder = AudioRecorder()
    @State private var isImporting = false
    @State private var errorMessage: String?

    /// Без ограничения тема с аудиоуроком легко станет сотнями мегабайт
    private static let maxFileSize = 30 * 1024 * 1024

    private var attached: PendingAudio? {
        block.audioClipID.flatMap { pendingAudio[$0] }
    }

    var body: some View {
        Picker("Источник", selection: $block.audioSource) {
            ForEach(TopicBlock.AudioSource.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: block.audioSource) { _, _ in
            if recorder.isRecording { _ = recorder.stop() }
            AudioClipPlayer.shared.stop()
        }

        TextField("Подпись, например «Произношение»", text: $block.text)

        switch block.audioSource {
        case .recording: recordingControls
        case .file: fileControls
        case .speech: speechControls
        }

        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundColor(.red)
        }
    }

    // Запись голосом — для авторов тем
    @ViewBuilder
    private var recordingControls: some View {
        if recorder.isDenied {
            Text("Нет доступа к микрофону. Разрешите его в Настройках iPhone → WordLearner.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        HStack {
            Button {
                if recorder.isRecording {
                    finishRecording()
                } else {
                    Task { await recorder.start() }
                }
            } label: {
                Label(recorder.isRecording ? "Остановить" : (attached == nil ? "Записать" : "Перезаписать"),
                      systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            Spacer()
            if recorder.isRecording {
                Text(TopicAudioView.format(recorder.elapsed))
                    .monospacedDigit()
                    .foregroundColor(.red)
            } else {
                previewButton
            }
        }
        // Запись дошла до предела и остановилась сама — сохраняем то, что записалось
        .onChange(of: recorder.isRecording) { wasRecording, isRecording in
            if wasRecording, !isRecording, attached == nil { finishRecording() }
        }
        .onDisappear {
            if recorder.isRecording { finishRecording() }
        }
    }

    // Готовый файл — для аудиоуроков
    @ViewBuilder
    private var fileControls: some View {
        HStack {
            Button {
                isImporting = true
            } label: {
                Label(attached == nil ? "Выбрать файл" : "Заменить файл", systemImage: "folder")
            }
            .buttonStyle(.borderless)
            Spacer()
            previewButton
        }
        if attached != nil, !block.audioFileName.isEmpty {
            Text(block.audioFileName)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        Color.clear.frame(height: 0)
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { importFile(url) }
            }
    }

    // Озвучка — услышать фразу целиком голосом приложения
    @ViewBuilder
    private var speechControls: some View {
        TextField("Английский текст, например «I have lost my keys»", text: $block.speechText, axis: .vertical)
            .textInputAutocapitalization(.never)
        Button {
            TextToSpeechManager.shared.speak(block.speechText)
        } label: {
            Label("Прослушать", systemImage: "speaker.wave.2.fill")
        }
        .buttonStyle(.borderless)
        .disabled(block.speechText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @ViewBuilder
    private var previewButton: some View {
        if let attached {
            let isPlaying = AudioClipPlayer.shared.playingID == block.id
            Button {
                AudioClipPlayer.shared.toggle(attached.data, id: block.id, fileExtension: attached.fileExtension)
            } label: {
                Label(isPlaying ? "Стоп" : "Прослушать", systemImage: isPlaying ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
        }
    }

    private func finishRecording() {
        guard let data = recorder.stop(), !data.isEmpty else {
            errorMessage = "Не получилось записать звук."
            return
        }
        attach(PendingAudio(data: data, fileExtension: "m4a"), fileName: "")
    }

    private func importFile(_ url: URL) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Не получилось открыть файл."
            return
        }
        guard data.count <= Self.maxFileSize else {
            errorMessage = "Файл больше 30 МБ — выберите покороче или сожмите его."
            return
        }
        guard AudioClipPlayer.duration(of: data) != nil else {
            errorMessage = "Этот файл не похож на звук, который умеет играть iPhone."
            return
        }
        attach(PendingAudio(data: data, fileExtension: url.pathExtension), fileName: url.lastPathComponent)
    }

    private func attach(_ audio: PendingAudio, fileName: String) {
        AudioClipPlayer.shared.stop()
        if let old = block.audioClipID { pendingAudio[old] = nil }
        let id = UUID()
        pendingAudio[id] = audio
        block.audioClipID = id
        block.audioFileName = fileName
        errorMessage = nil
    }
}
