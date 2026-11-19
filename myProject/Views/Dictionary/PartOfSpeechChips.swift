import SwiftUI

/// Часть речи в формах слова: четыре основные и «другое» (prep., pron., phr. v. … — вписывается вручную)
enum PartOfSpeechChoice: CaseIterable, Identifiable {
    case noun, verb, adjective, adverb, other

    var id: Self { self }

    var title: String {
        switch self {
        case .noun: "сущ."
        case .verb: "глаг."
        case .adjective: "прил."
        case .adverb: "нареч."
        case .other: "другое"
        }
    }

    /// Так часть речи хранится в слове; у «другого» кода нет — его вписывают сами
    var code: String? {
        switch self {
        case .noun: "n."
        case .verb: "v."
        case .adjective: "adj."
        case .adverb: "adv."
        case .other: nil
        }
    }

    /// nil — часть речи не задана
    static func choice(for code: String) -> PartOfSpeechChoice? {
        let code = code.trimmingCharacters(in: .whitespaces)
        if code.isEmpty { return nil }
        return allCases.first { $0.code == code } ?? .other
    }
}

/// Ряд чипов «сущ. / глаг. / прил. / нареч. / другое»; у «другого» ниже появляется поле для кода
struct PartOfSpeechChips: View {
    @Binding var code: String
    /// Нажали «другое», но код ещё не вписан
    @State private var otherTapped = false

    private var selection: PartOfSpeechChoice? {
        otherTapped ? .other : PartOfSpeechChoice.choice(for: code)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LXSectionLabel(text: "Часть речи")
            FlowLayout(spacing: 8, centered: false) {
                ForEach(PartOfSpeechChoice.allCases) { choice in
                    LXChip(title: choice.title, isOn: selection == choice) { tap(choice) }
                }
            }
            if selection == .other {
                LXField(label: "Код части речи") {
                    TextField("prep., pron., phr. v. …", text: $code)
                        .scaledFont(size: 16)
                        .foregroundStyle(Color.brandDark)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    private func tap(_ choice: PartOfSpeechChoice) {
        if choice == .other {
            if PartOfSpeechChoice.choice(for: code).map({ $0 != .other }) ?? false { code = "" }
            otherTapped = true
        } else if selection == choice {
            code = ""
            otherTapped = false
        } else {
            code = choice.code ?? ""
            otherTapped = false
        }
    }
}
