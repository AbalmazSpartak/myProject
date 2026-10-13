import SwiftUI

/// «Сообщить об ошибке» в слове из встроенного словаря: что не так и комментарий
struct ReportWordView: View {
    @Environment(\.dismiss) private var dismiss
    let word: Word

    @State private var field = WordReports.Field.translation
    @State private var comment = ""
    @State private var state: SendState = .editing

    private enum SendState { case editing, sending, sent, queued }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(word.english)
                                .scaledFont(size: 20, weight: .semibold, design: .serif)
                                .foregroundColor(.brandDark)
                            Text("\(word.transcription.isEmpty ? "" : "[\(word.transcription)] · ")\(word.russian)")
                                .scaledFont(size: 15)
                                .foregroundColor(.gray)
                        }
                    }
                    Section("Что не так") {
                        Picker("Что не так", selection: $field) {
                            ForEach(WordReports.Field.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    Section {
                        TextField("Например: правильно «бежать», а не «бегать»", text: $comment, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("Комментарий")
                    } footer: {
                        Text("Слово и его текущие данные приложатся сами. Без интернета сообщение сохранится и уйдёт позже.")
                    }
                    if state == .sent || state == .queued {
                        Section {
                            Label(state == .sent ? "Отправлено — спасибо!" : "Сохранено, отправится, когда появится интернет",
                                  systemImage: state == .sent ? "checkmark.circle.fill" : "clock.fill")
                                .foregroundColor(state == .sent ? .green : .orange)
                        }
                    }
                }
                .listRowBackground(Color.cardBackground)
            }
            .brandListBackground()
            .navigationTitle("Сообщить об ошибке")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(state == .sent || state == .queued ? "Закрыть" : "Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if state == .editing || state == .sending {
                        Button("Отправить") { send() }
                            .bold()
                            .disabled(state == .sending)
                    }
                }
            }
        }
    }

    private func send() {
        state = .sending
        let report = WordReports.report(word, field: field, comment: comment)
        Task {
            state = await WordReports.submit(report) ? .sent : .queued
            Haptics.tap()
        }
    }
}
