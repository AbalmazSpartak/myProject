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
        Toggle("Столбец подписей", isOn: $table.hasHeaderColumn)
        if table.hasHeaderColumn {
            Picker("Подписи", selection: $table.labelsOnRight) {
                Text("Слева").tag(false)
                Text("Справа").tag(true)
            }
            .pickerStyle(.segmented)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            SpanGridLayout(rows: table.rows, columns: table.columns, minColumnWidth: 110, maxColumnWidth: 360) {
                ForEach(table.visibleCells) { cell in
                    cellField(cell)
                        .gridCellPlacement(GridCellPlacement(row: cell.row, column: cell.column,
                                                             rowSpan: cell.style.rowSpan, columnSpan: cell.style.columnSpan))
                }
            }
            .padding(.vertical, 4)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Как будет выглядеть")
                .font(.footnote)
                .foregroundColor(.secondary)
            TopicTableView(table: table)
        }
    }

    private func cellField(_ cell: TopicTable.Cell) -> some View {
        let (row, column, style) = (cell.row, cell.column, cell.style)
        let isHeader = table.isHeader(row: row, column: column)
        let parts = table.parts(row: row, column: column)
        return VStack(alignment: .leading, spacing: 2) {
            if parts.isEmpty {
                // В ячейке может быть несколько строк: «I / you / we / they» — каждое с новой строки
                TextField("", text: Binding(
                    get: { row < table.rows && column < table.columns ? table.cells[row][column] : "" },
                    set: { if row < table.rows && column < table.columns { table.cells[row][column] = $0 } }
                ), axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(isHeader ? .body.weight(.semibold) : .body)
                .italic(style.italic)
                .foregroundColor(TableCellAppearance.color(style.tone))
                .multilineTextAlignment(TableCellAppearance.textAlignment(style.alignment))
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(parts.indices, id: \.self) { index in
                        partField(index, part: parts[index], row: row, column: column, cellStyle: style, isHeader: isHeader)
                    }
                }
            }

            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if style.vertical {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                cellMenu(row: row, column: column, style: style)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isHeader ? Color.brandAccent.opacity(0.6) : Color.brandInputBg)
        .cornerRadius(6)
        .padding(3)
    }

    /// ⋯ у ячейки: объединение и оформление
    private func cellMenu(row: Int, column: Int, style: TableCellStyle) -> some View {
        func update(_ change: (inout TableCellStyle) -> Void) {
            var style = table.style(row: row, column: column)
            change(&style)
            table.setStyle(style, row: row, column: column)
        }
        return Menu {
            Section {
                Button { table.mergeRight(row: row, column: column) } label: {
                    Label("Объединить вправо", systemImage: "arrow.right.to.line")
                }
                .disabled(!table.canMergeRight(row: row, column: column))
                Button { table.mergeDown(row: row, column: column) } label: {
                    Label("Объединить вниз", systemImage: "arrow.down.to.line")
                }
                .disabled(!table.canMergeDown(row: row, column: column))
                if style.rowSpan > 1 || style.columnSpan > 1 {
                    Button { table.split(row: row, column: column) } label: {
                        Label("Отменить объединение", systemImage: "square.split.2x2")
                    }
                }
            }
            Section {
                // «Will | I…she | love?» в одной ячейке — без пробелов для выравнивания
                Menu {
                    ForEach(TopicTable.partRange, id: \.self) { count in
                        Button("\(count) столбца") { table.splitIntoParts(count, row: row, column: column) }
                            .disabled(table.parts(row: row, column: column).count == count)
                    }
                } label: {
                    Label("Разделить на столбцы", systemImage: "rectangle.split.3x1")
                }
                if !table.parts(row: row, column: column).isEmpty {
                    Button { table.removeParts(row: row, column: column) } label: {
                        Label("Убрать столбцы", systemImage: "rectangle")
                    }
                }
            }
            Section {
                Picker("Цвет", selection: Binding(get: { style.tone }, set: { tone in update { $0.tone = tone } })) {
                    ForEach(TableCellStyle.Tone.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                Picker("Выравнивание", selection: Binding(get: { style.alignment }, set: { alignment in update { $0.alignment = alignment } })) {
                    ForEach(TableCellStyle.Alignment.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                Toggle("Курсив", isOn: Binding(get: { style.italic }, set: { italic in update { $0.italic = italic } }))
                Toggle("Вертикально", isOn: Binding(get: { style.vertical }, set: { vertical in update { $0.vertical = vertical } }))
            }
        } label: {
            Image(systemName: style == TableCellStyle() ? "ellipsis.circle" : "ellipsis.circle.fill")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Ячейка: объединение и оформление")
    }

    /// Столбец внутри ячейки: поле и своё оформление
    private func partField(_ index: Int, part: TableCellPart, row: Int, column: Int,
                           cellStyle: TableCellStyle, isHeader: Bool) -> some View {
        func update(_ change: (inout TableCellPart) -> Void) {
            let current = table.parts(row: row, column: column)
            guard current.indices.contains(index) else { return }
            var part = current[index]
            change(&part)
            table.setPart(part, at: index, row: row, column: column)
        }
        return VStack(alignment: .leading, spacing: 2) {
            TextField("", text: Binding(
                get: { table.parts(row: row, column: column).indices.contains(index) ? table.parts(row: row, column: column)[index].text : "" },
                set: { text in update { $0.text = text } }
            ), axis: .vertical)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(isHeader ? .body.weight(.semibold) : .body)
            .italic(part.italic || cellStyle.italic)
            .foregroundColor(TableCellAppearance.color(part.tone == .normal ? cellStyle.tone : part.tone))
            .multilineTextAlignment(TableCellAppearance.textAlignment(part.alignment))
            .padding(4)
            .frame(minWidth: 70, idealWidth: 80, maxWidth: .infinity, alignment: .topLeading)
            .background(Color.cardBackground.opacity(0.7))
            .cornerRadius(4)

            HStack {
                Spacer(minLength: 0)
                Menu {
                    Picker("Цвет", selection: Binding(get: { part.tone }, set: { tone in update { $0.tone = tone } })) {
                        ForEach(TableCellStyle.Tone.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("Выравнивание", selection: Binding(get: { part.alignment }, set: { alignment in update { $0.alignment = alignment } })) {
                        ForEach(TableCellStyle.Alignment.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Toggle("Курсив", isOn: Binding(get: { part.italic }, set: { italic in update { $0.italic = italic } }))
                } label: {
                    Image(systemName: "paintbrush")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Оформление столбца \(index + 1)")
                Spacer(minLength: 0)
            }
        }
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
