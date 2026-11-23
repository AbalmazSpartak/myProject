import SwiftUI

/// Настройки → «Обучение»: направление перевода, картинки, вибрация, размер подхода, словари, перевод слов из книг, улучшение словаря
struct LearningSettingsView: View {
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    @AppStorage("show_word_images") private var showWordImages: Bool = true
    @AppStorage(DictionarySignals.enabledKey) private var improveDictionary = true
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue

    var body: some View {
        LXForm {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Направление перевода")
                        .scaledFont(size: 14)
                        .foregroundColor(Color.brandMuted)

                    Picker("Направление перевода", selection: $translationMode) {
                        Text("Англ ➔ Рус").tag("en_ru")
                        Text("Рус ➔ Англ").tag("ru_en")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)

                Toggle("Картинки к словам", isOn: $showWordImages)

                Toggle("Вибрация", isOn: $hapticsEnabled)

                Picker("Слов за подход", selection: $sessionLength) {
                    ForEach(SessionLength.options, id: \.self) { length in
                        Text(length == 0 ? "Все" : "\(length)").tag(length)
                    }
                }

                NavigationLink {
                    StudyDictionariesView()
                } label: {
                    LabeledContent("Словари", value: studyScope.isEverythingEnabled ? "Все" : "Выбранные")
                }

                NavigationLink {
                    BookTranslationSettingsView()
                } label: {
                    Label("Перевод слов из книг", systemImage: "character.bubble")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Помогать улучшать словарь", isOn: $improveDictionary)
                    Text("Анонимно, без имени и почты: ваши правки слов из встроенного словаря, слова, добавленные из книг (с предложением), и слова, которые долго не запоминаются. По ним исправляются переводы для всех.")
                        .scaledFont(size: 12)
                        .foregroundColor(Color.brandMuted)
                        .textSelection(.enabled)
                }
            } footer: {
                Text("Новые слова в «На повторение» идут от простых к сложным, счётчик обнуляется в полночь. После подхода можно продолжить или вернуться в меню.")
                    .textSelection(.enabled)
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Обучение")
        .navigationBarTitleDisplayMode(.inline)
    }
}
