import SwiftUI

/// Тренировка к теме «Как читаются гласные»: слово с выделенной гласной → какой звук.
/// Варианты — четыре звука этой буквы из таблицы; ошибка объясняется типом слога
enum VowelReading {
    enum SyllableType: CaseIterable {
        case open, closed, r, re

        var title: String {
            switch self {
            case .open: return "Открытый слог"
            case .closed: return "Закрытый слог"
            case .r: return "Гласная + r"
            case .re: return "Гласная + re"
            }
        }

        var rule: String {
            switch self {
            case .open: return "слог кончается на гласную или после согласной идёт немая e — гласная звучит как в алфавите"
            case .closed: return "после гласной согласная — звук короткий"
            case .r: return "r после гласной не читается, звук долгий"
            case .re: return "после r ещё гласная — звук с [ə] на конце (у o — [ɔ:])"
            }
        }
    }

    /// Буква, её звуки по типам слога и слова: нужная гласная — в квадратных скобках, «c[a]r»
    struct Vowel {
        let letter: String
        let sounds: [SyllableType: String]
        let words: [SyllableType: [String]]
    }

    static let vowels: [Vowel] = [
        Vowel(letter: "a",
              sounds: [.open: "[ei]", .closed: "[æ]", .r: "[a:]", .re: "[ɛə]"],
              words: [.open: ["n[a]me", "t[a]ke", "b[a]by", "l[a]ke", "g[a]me", "c[a]ke", "pl[a]te", "g[a]te"],
                      .closed: ["c[a]t", "f[a]t", "r[a]t", "m[a]p", "b[a]g", "h[a]t", "l[a]mp", "h[a]nd"],
                      .r: ["c[a]r", "f[a]r", "d[a]rk", "p[a]rk", "st[a]r", "f[a]rm", "c[a]rd", "[a]rt"],
                      .re: ["h[a]re", "c[a]re", "d[a]re", "sh[a]re", "b[a]re", "r[a]re", "squ[a]re", "st[a]re"]]),
        Vowel(letter: "o",
              sounds: [.open: "[əʊ]", .closed: "[ɔ]", .r: "[ɔ:]", .re: "[ɔ:]"],
              words: [.open: ["h[o]pe", "h[o]me", "R[o]me", "n[o]se", "r[o]se", "b[o]ne", "n[o]te", "g[o]"],
                      .closed: ["h[o]t", "d[o]g", "st[o]p", "b[o]x", "p[o]t", "fr[o]g", "cl[o]ck", "l[o]t"],
                      .r: ["f[o]r", "sp[o]rt", "h[o]rse", "f[o]rk", "c[o]rn", "sh[o]rt", "b[o]rn", "n[o]rth"],
                      .re: ["m[o]re", "bef[o]re", "sc[o]re", "st[o]re", "c[o]re", "sh[o]re"]]),
        Vowel(letter: "u",
              sounds: [.open: "[ju:]", .closed: "[ʌ]", .r: "[ɜ:]", .re: "[jʊə]"],
              words: [.open: ["c[u]te", "c[u]be", "comp[u]ter", "t[u]be", "m[u]sic", "h[u]ge", "[u]se"],
                      .closed: ["c[u]p", "b[u]s", "l[u]nch", "s[u]n", "r[u]n", "d[u]ck", "c[u]t", "b[u]t"],
                      .r: ["t[u]rkey", "h[u]rt", "l[u]rk", "t[u]rn", "b[u]rn", "ch[u]rch", "f[u]r", "n[u]rse"],
                      .re: ["c[u]re", "p[u]re", "end[u]re", "sec[u]re"]]),
        Vowel(letter: "e",
              sounds: [.open: "[i:]", .closed: "[e]", .r: "[ɜ:]", .re: "[ɪə]"],
              words: [.open: ["m[e]", "w[e]", "th[e]me", "h[e]", "sh[e]", "b[e]", "P[e]te", "th[e]se"],
                      .closed: ["m[e]t", "p[e]t", "l[e]t", "b[e]d", "r[e]d", "p[e]n", "t[e]n", "[e]gg"],
                      .r: ["G[e]rman", "p[e]rfume", "v[e]rb", "h[e]r", "t[e]rm", "h[e]rb", "s[e]rve"],
                      .re: ["h[e]re", "m[e]re", "sph[e]re", "sev[e]re"]]),
        Vowel(letter: "i",
              sounds: [.open: "[ai]", .closed: "[i]", .r: "[ɜ:]", .re: "[aiə]"],
              words: [.open: ["w[i]fe", "b[i]ke", "k[i]te", "t[i]me", "n[i]ne", "l[i]ne", "r[i]de", "f[i]ve"],
                      .closed: ["k[i]t", "l[i]t", "f[i]t", "b[i]g", "s[i]t", "m[i]lk", "p[i]n", "f[i]sh"],
                      .r: ["g[i]rl", "b[i]rd", "f[i]rst", "sh[i]rt", "s[i]r", "th[i]rd"],
                      .re: ["f[i]re", "t[i]red", "h[i]re", "w[i]re", "des[i]re"]]),
        Vowel(letter: "y",
              sounds: [.open: "[ai]", .closed: "[i]", .r: "[ɜ:]", .re: "[aiə]"],
              words: [.open: ["fl[y]", "wh[y]", "m[y]", "b[y]", "tr[y]", "t[y]pe", "st[y]le"],
                      .closed: ["t[y]pical", "s[y]stem", "m[y]th", "g[y]m", "s[y]mbol"],
                      .r: ["M[y]rtle"],
                      .re: ["t[y]re", "l[y]re"]]),
    ]

    struct Task: Identifiable {
        let id = UUID()
        let vowel: Vowel
        let type: SyllableType
        let marked: String

        var word: String { marked.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "") }
        var answer: String { vowel.sounds[type] ?? "" }
        /// Звуки этой буквы без повторов: у o перед r и re звук один — [ɔ:]
        var options: [String] {
            var seen: Set<String> = []
            return SyllableType.allCases.compactMap { vowel.sounds[$0] }.filter { seen.insert($0).inserted }
        }
    }

    /// Раунд: разные пары «буква + тип слога» (их 24), в каждой — случайное слово
    static func round(count: Int = 15) -> [Task] {
        let pairs = vowels.flatMap { vowel in SyllableType.allCases.map { (vowel, $0) } }.shuffled()
        return pairs.prefix(count).compactMap { vowel, type in
            (vowel.words[type]?.randomElement()).map { Task(vowel: vowel, type: type, marked: $0) }
        }
    }
}

/// Экран тренировки «Как читается?»
struct VowelReadingExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tasks = VowelReading.round()
    @State private var index = 0
    @State private var chosen: String?
    @State private var correctCount = 0

    private var task: VowelReading.Task? { tasks.indices.contains(index) ? tasks[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Закрыть") { dismiss() }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                Spacer()
                if task != nil {
                    Text("\(index + 1) из \(tasks.count)")
                        .scaledFont(size: 15, weight: .semibold, design: .rounded)
                        .foregroundColor(.gray)
                }
                Spacer()
                Color.clear.frame(width: 70, height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if let task {
                question(task)
            } else {
                finished
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }

    private func question(_ task: VowelReading.Task) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 14) {
                    Text(Self.highlighted(task.marked))
                        .scaledFont(size: 46, design: .serif)
                        .foregroundColor(.brandDark)
                    Button { TextToSpeechManager.shared.speak(task.word) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .scaledFont(size: 18, weight: .semibold)
                            .foregroundColor(.brandDark)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.brandFill))
                    }
                    .accessibilityLabel("Произнести слово")
                }
                .padding(.top, 24)

                Text("Как здесь читается ") + Text(task.vowel.letter).bold().foregroundColor(TopicText.highlight) + Text("?")

                VStack(spacing: 12) {
                    ForEach(task.options, id: \.self) { option in
                        optionButton(option, task: task)
                    }
                }

                if let chosen {
                    explanation(task, isCorrect: chosen == task.answer)
                    Button {
                        self.chosen = nil
                        index += 1
                    } label: {
                        Text("Дальше")
                            .scaledFont(size: 18, weight: .bold)
                            .foregroundColor(.brandBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.brandDark))
                    }
                }
            }
            .scaledFont(size: 18)
            .foregroundColor(.brandDark)
            .padding(20)
            .animation(.snappy(duration: 0.2), value: chosen)
        }
    }

    private func optionButton(_ option: String, task: VowelReading.Task) -> some View {
        let isAnswer = option == task.answer
        let fill: Color = {
            guard let chosen else { return .cardBackground }
            if isAnswer { return .green.opacity(0.25) }
            return option == chosen ? .red.opacity(0.2) : .cardBackground
        }()
        return Button {
            guard chosen == nil else { return }
            chosen = option
            if isAnswer { correctCount += 1 }
            UINotificationFeedbackGenerator().notificationOccurred(isAnswer ? .success : .warning)
            TextToSpeechManager.shared.speak(task.word)
        } label: {
            Text(option)
                .scaledFont(size: 24, weight: .medium, design: .serif)
                .foregroundColor(.brandDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(chosen != nil && isAnswer ? Color.green : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private func explanation(_ task: VowelReading.Task, isCorrect: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(isCorrect ? "Верно!" : "Здесь \(task.answer)",
                  systemImage: isCorrect ? "checkmark.circle.fill" : "lightbulb.fill")
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(isCorrect ? .green : .orange)
            Text("\(task.type.title): \(task.type.rule).")
                .scaledFont(size: 15)
                .foregroundColor(.brandDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardBackground))
    }

    private var finished: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🎉").font(.system(size: 64))
            Text("Тренировка пройдена")
                .scaledFont(size: 28, design: .serif)
                .foregroundColor(.brandDark)
            Text("Верно: \(correctCount) из \(tasks.count)")
                .scaledFont(size: 17)
                .foregroundColor(.gray)
            Spacer()
            Button {
                tasks = VowelReading.round()
                index = 0
                correctCount = 0
            } label: {
                Text("Ещё раунд")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(.brandBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color.brandDark))
            }
            Button("К уроку") { dismiss() }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandTint)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }

    /// «c[a]r» → car с выделенной a
    static func highlighted(_ marked: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(marked)
        while let open = rest.firstIndex(of: "["), let close = rest[open...].firstIndex(of: "]") {
            result += AttributedString(String(rest[..<open]))
            var letter = AttributedString(String(rest[rest.index(after: open)..<close]))
            letter.foregroundColor = TopicText.highlight
            letter.underlineStyle = .single
            result += letter
            rest = rest[rest.index(after: close)...]
        }
        result += AttributedString(String(rest))
        return result
    }
}

/// Блок «Тренировка» в теме: карточка, которая открывает упражнение
struct TopicExerciseCard: View {
    let block: TopicBlock
    @State private var isOpen = false

    var body: some View {
        Button { isOpen = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .scaledFont(size: 26)
                    .foregroundColor(.brandDark)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.brandAccent))
                VStack(alignment: .leading, spacing: 3) {
                    Text(block.text.isEmpty ? "Тренировка" : block.text)
                        .scaledFont(size: 18, weight: .semibold, design: .serif)
                        .foregroundColor(.brandDark)
                    Text("15 слов: выберите, как читается выделенная гласная")
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $isOpen) {
            switch block.exerciseID {
            case VowelReading.exerciseID?: VowelReadingExerciseView().appThemedColorScheme()
            default: Text("Тренировка недоступна в этой версии").padding()
            }
        }
    }
}

extension VowelReading {
    static let exerciseID = "vowelReading"
}
