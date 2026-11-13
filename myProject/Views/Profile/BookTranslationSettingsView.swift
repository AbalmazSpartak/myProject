import SwiftUI

/// Настройки → «Перевод слов из книг»: переводчик iOS для выделенных слов, ИИ-подсказки, перевод слов при создании словаря из книги
struct BookTranslationSettingsView: View {
    @AppStorage(ReaderSelectionPanel.systemTranslatorKey) private var selectionSystemTranslator = false
    @AppStorage(CloudContext.enabledKey) private var aiHints = false
    @AppStorage(CloudContext.qualityKey) private var aiHintsQuality = CloudContext.Quality.normal.rawValue
    @AppStorage(BookWordsAI.choiceKey) private var bookWordsTranslator = ""

    var body: some View {
        Form {
            Group {
                Section {
                    Toggle("Переводчик iOS для выделенных слов", isOn: $selectionSystemTranslator)
                } footer: {
                    Text("По умолчанию слово, выделенное в книге, переводится из словаря приложения. Если включить, в панели выделения появится кнопка «Перевести»: встроенный переводчик iOS. Он переводит слово без контекста и иногда ошибается, например, «do» → «вечеринка».")
                        .textSelection(.enabled)
                }

                Section {
                    Toggle("ИИ-подсказки", isOn: $aiHints)
                    if aiHints {
                        Picker("Подсказка", selection: $aiHintsQuality) {
                            ForEach(CloudContext.Quality.allCases, id: \.self) { quality in
                                Text(quality.title).tag(quality.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    Text(aiHints
                         ? "Кнопка «Значение в этом предложении» в карточке слова в читалке. Слово и предложение уходят на сервер WordLearner (ИИ Claude), без имени и почты. Обычная — быстрая; более точная — точнее подбирает значение и тратит 3 подсказки из дневного запаса вместо одной. Где есть Apple Intelligence, значение показывается сразу и бесплатно."
                         : "Перевод слова именно в этом предложении — в карточке слова в читалке.")
                        .textSelection(.enabled)
                }

                Section {
                    Picker("Слова из книг", selection: $bookWordsTranslator) {
                        Text("Спрашивать").tag("")
                        Text("ИИ").tag("ai")
                        Text("Встроенный").tag("apple")
                    }
                } footer: {
                    Text("Перевод новых слов, когда словарь создаётся из книги или файла. ИИ переводит в значении из предложения и понимает диалект; нужен интернет, слово и предложение уходят на сервер WordLearner без имени и почты.")
                        .textSelection(.enabled)
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Перевод слов из книг")
        .navigationBarTitleDisplayMode(.inline)
    }
}
