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

/// **жирный** и *курсив* в тексте и ячейках таблиц
enum TopicText {
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Таблица

/// Таблица с тонкими линиями; шире экрана — листается вбок
struct TopicTableView: View {
    let table: TopicTable

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<table.rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<table.columns, id: \.self) { column in
                            cell(row: row, column: column)
                        }
                    }
                }
            }
            .background(Color.cardBackground)
            .overlay(Rectangle().stroke(Color.brandDark.opacity(0.25), lineWidth: 1))
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func cell(row: Int, column: Int) -> some View {
        let isHeader = (table.hasHeaderRow && row == 0) || (table.hasHeaderColumn && column == 0)
        return Text(TopicText.attributed(table.cells[row][column]))
            .scaledFont(size: 16, weight: isHeader ? .semibold : .regular, design: .serif)
            .foregroundColor(.brandDark)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 64, maxWidth: .infinity, maxHeight: .infinity)
            .background(isHeader ? Color.brandFill : Color.clear)
            .overlay(Rectangle().stroke(Color.brandDark.opacity(0.18), lineWidth: 0.5))
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
