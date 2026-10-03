import SwiftUI

/// Блок темы на экране чтения
struct TopicBlockView: View {
    let block: TopicBlock
    let clip: TopicAudioClip?

    var body: some View {
        switch block.kind {
        case .heading:
            if !block.text.isEmpty {
                Text(block.text)
                    .scaledFont(size: 23, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .padding(.top, 6)
            }
        case .text:
            if !block.text.isEmpty {
                Text(TopicText.attributed(block.text))
                    .scaledFont(size: 17, design: .serif)
                    .foregroundColor(.brandDark)
                    .textSelection(.enabled)
            }
        case .table:
            TopicTableView(table: block.table)
        case .audio:
            TopicAudioView(block: block, clip: clip)
        }
    }
}

/// Разметка текста и ячеек: **жирный**, *курсив*, ==красный==
enum TopicText {
    static let highlight = Color(red: 0.80, green: 0.18, blue: 0.16)

    static func attributed(_ text: String) -> AttributedString {
        var parts = text.components(separatedBy: "==")
        // Непарное «==» оставляем как есть
        if parts.count.isMultiple(of: 2), let last = parts.popLast() {
            parts[parts.count - 1] += "==" + last
        }
        var result = AttributedString()
        for (index, part) in parts.enumerated() where !part.isEmpty {
            var piece = markdown(part)
            if !index.isMultiple(of: 2) { piece.foregroundColor = highlight }
            result += piece
        }
        return result
    }

    /// Без разметки — для вертикальной подписи, где каждая буква на своей строке
    static func plain(_ text: String) -> String {
        String(attributed(text).characters)
    }

    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Таблица

/// Таблица с тонкими линиями и объединёнными ячейками: уже экрана — растягивается по ширине, шире — листается вбок
struct TopicTableView: View {
    let table: TopicTable

    /// Ширина места под таблицу — узкая таблица растягивается до неё
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            SpanGridLayout(rows: table.rows, columns: table.columns, fillWidth: availableWidth) {
                ForEach(table.visibleCells) { cell in
                    cellView(cell)
                        .gridCellPlacement(GridCellPlacement(row: cell.row, column: cell.column,
                                                             rowSpan: cell.style.rowSpan, columnSpan: cell.style.columnSpan))
                }
            }
            .background(Color.cardBackground)
            .overlay(Rectangle().stroke(Color.brandDark.opacity(0.25), lineWidth: 1))
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        // Не onGeometryChange: его замыкание iOS может вызвать из фонового потока отрисовки, а Swift 6 на этом
        // останавливает приложение (как было с AsyncImage). onAppear/onChange — всегда на главном потоке
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { availableWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in availableWidth = width }
            }
        }
    }

    private func cellView(_ cell: TopicTable.Cell) -> some View {
        let style = cell.style
        let isHeader = table.isHeader(row: cell.row, column: cell.column)
        let parts = table.parts(row: cell.row, column: cell.column)
        return Group {
            if parts.isEmpty {
                singleText(table.cells[cell.row][cell.column], style: style, isHeader: isHeader)
            } else {
                // Столбцы внутри ячейки — каждый своей ширины, без линий, по центру по высоте;
                // лишнее место ячейки — поровну между столбцами
                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                        if index > 0 { Spacer(minLength: 10) }
                        partText(part, cellStyle: style, isHeader: isHeader)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(isHeader ? Color.brandFill : Color.clear)
        .overlay(Rectangle().stroke(Color.brandDark.opacity(0.18), lineWidth: 0.5))
    }

    private func singleText(_ raw: String, style: TableCellStyle, isHeader: Bool) -> some View {
        let text = style.vertical
            ? AttributedString(TopicText.plain(raw).map(String.init).joined(separator: "\n"))
            : TopicText.attributed(raw)
        return Text(text)
            .scaledFont(size: 16, weight: isHeader ? .semibold : .regular, design: .serif)
            .italic(style.italic)
            .foregroundColor(TableCellAppearance.color(style.tone))
            .multilineTextAlignment(style.vertical ? .center : TableCellAppearance.textAlignment(style.alignment))
            .padding(.horizontal, style.vertical ? 6 : 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: style.vertical ? .center : TableCellAppearance.frameAlignment(style.alignment))
    }

    private func partText(_ part: TableCellPart, cellStyle: TableCellStyle, isHeader: Bool) -> some View {
        Text(TopicText.attributed(part.text))
            .scaledFont(size: 16, weight: isHeader ? .semibold : .regular, design: .serif)
            .italic(part.italic || cellStyle.italic)
            .foregroundColor(TableCellAppearance.color(part.tone == .normal ? cellStyle.tone : part.tone))
            .multilineTextAlignment(TableCellAppearance.textAlignment(part.alignment))
            // Строки части не переносятся — «love?» и «Does» не рвутся; новые строки автор ставит сам
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Цвет и выравнивание ячейки — общие для таблицы и её редактора
enum TableCellAppearance {
    static func color(_ tone: TableCellStyle.Tone) -> Color {
        switch tone {
        case .normal: return .brandDark
        case .red: return TopicText.highlight
        case .gray: return .gray
        }
    }

    static func textAlignment(_ alignment: TableCellStyle.Alignment) -> TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    static func frameAlignment(_ alignment: TableCellStyle.Alignment) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// MARK: - Аудио

/// Кнопка «слушать» для записи, файла или озвучки текста
struct TopicAudioView: View {
    let block: TopicBlock
    let clip: TopicAudioClip?

    private var player: AudioClipPlayer { .shared }
    private var isPlaying: Bool { player.playingID == block.id }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: play) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .scaledFont(size: 40)
                    .foregroundColor(.cyan)
            }
            .buttonStyle(.plain)
            .disabled(!isPlayable)
            .accessibilityLabel(isPlaying ? "Остановить" : "Слушать")

            VStack(alignment: .leading, spacing: 4) {
                if !block.text.isEmpty {
                    Text(block.text)
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.brandDark)
                }
                if block.audioSource == .speech {
                    Text(block.speechText)
                        .scaledFont(size: 16, design: .serif)
                        .italic()
                        .foregroundColor(.brandDark)
                } else if let clip, let duration = AudioClipPlayer.duration(of: clip.data) {
                    Text(Self.format(duration))
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                } else {
                    Text("Звук не прикреплён")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .onDisappear { if isPlaying { player.stop() } }
    }

    private var isPlayable: Bool {
        block.audioSource == .speech ? !block.speechText.isEmpty : clip != nil
    }

    private func play() {
        if block.audioSource == .speech {
            TextToSpeechManager.shared.speak(block.speechText)
        } else if let clip {
            player.toggle(clip.data, id: block.id, fileExtension: clip.fileExtension)
        }
    }

    static func format(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
