import SwiftUI
import SwiftData

/// «Обзор» — главный экран: шапка, «Фокус дня» (главное занятие одной кнопкой), слово дня,
/// «Быстрый доступ» к разделам и «Ваши подборки». Что показывать — Настройки → «Обзор»
struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    /// Темы сообщества, добавленные в «Ваши подборки»
    @Query(filter: #Predicate<CommunityTopic> { $0.savedAt != nil }, sort: \CommunityTopic.savedAt, order: .reverse)
    private var savedTopics: [CommunityTopic]
    @AppStorage(OverviewLayout.storageKey) private var layout = OverviewLayout.standard
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    @Query private var profiles: [UserProfile]
    @AppStorage(DailyNewWords.limitKey) private var dailyLimit = DailyNewWords.defaultLimit

    @State private var wordOfDay: Word?
    @State private var streak = 0
    @State private var introducedToday = 0
    @State private var dueCount = 0
    /// Какая карточка «Фокуса дня» видна; при запуске — средняя
    @State private var focusPage: Int?

    let open: (ActiveScreen) -> Void
    /// Нажатие на шапку — экран «Профиль»
    var openProfile: () -> Void = {}

    /// Сколько подборок видно на «Обзоре»; остальные — по кнопке «Все»
    private static let collectionsShown = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                focusCarousel

                if layout.showsWordOfDay, let wordOfDay {
                    block("Слово дня") { WordOfDayRow(word: wordOfDay) }
                }

                if !layout.quickAccess.isEmpty {
                    block("Быстрый доступ") { quickAccess }
                }

                // Пустой блок не показывается: темы добавляются кнопкой «В мои подборки» в «Сообществе»
                if layout.showsCollections, !savedTopics.isEmpty {
                    block("Ваши подборки", action: ("Все", { open(.bookmarks) })) { collections }
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 30)
        }
        // Шапка закреплена сверху: лента прокручивается под ней
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            // Новый раздел один раз появляется в «Быстром доступе» сам — дальше его можно убрать в настройках «Обзора»
            if !UserDefaults.standard.bool(forKey: "overview_added_schulte") {
                UserDefaults.standard.set(true, forKey: "overview_added_schulte")
                if !layout.quickAccess.contains(.schulte) { layout.quickAccess.append(.schulte) }
            }
            if !UserDefaults.standard.bool(forKey: "overview_added_speak") {
                UserDefaults.standard.set(true, forKey: "overview_added_speak")
                if !layout.quickAccess.contains(.speak) { layout.quickAccess.append(.speak) }
            }
            // Серия, норма и слова к повторению меняются в тренировках — пересчитываем при каждом возвращении на «Обзор»
            streak = DailyStreak.current()
            introducedToday = DailyNewWords.introducedToday
            if layout.focusSections.contains(.flashcards) {
                dueCount = StudyWords.count(StudyWords.all(StudyWords.scope(studyScope), StudyWords.isDue(now: Date())),
                                            in: modelContext)
            }
            // Скрытое «Слово дня» — слова не загружаем; включат в настройках — загрузим при возврате на «Обзор»
            if wordOfDay == nil, layout.showsWordOfDay {
                wordOfDay = WordOfDay.recent(days: 1, from: modelContext.fetchAllWords()).first
            }
        }
    }

    // MARK: - Фокус дня

    /// Карусель до трёх карточек: листается свайпом, соседняя чуть видна, под ней — точки
    @ViewBuilder
    private var focusCarousel: some View {
        let sections = layout.focusSections
        if sections.count == 1, let section = sections.first {
            focusCard(section)
                .padding(.horizontal, 20)
        } else {
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            // Карточки одной высоты — по самой высокой, содержимое по центру
                            focusCard(section)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollPosition(id: $focusPage)
                .onAppear {
                    if focusPage == nil { focusPage = sections.count / 2 }
                }

                HStack(spacing: 7) {
                    ForEach(sections.indices, id: \.self) { index in
                        Circle()
                            .fill(index == (focusPage ?? 0) ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    private func focusCard(_ section: MenuSection) -> some View {
        FocusCard(section: section, dueCount: dueCount, introducedToday: introducedToday, dailyLimit: dailyLimit) {
            open(section.screen)
        }
    }

    /// Заголовок прописными (справа — кнопка, если есть) и содержимое
    private func block<Content: View>(_ title: String, action: (title: String, run: () -> Void)? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased())
                    .scaledFont(size: 17, weight: .bold)
                    .foregroundColor(.brandDark)
                Spacer()
                if let action {
                    Button {
                        Haptics.tap()
                        action.run()
                    } label: {
                        Text(action.title)
                            .scaledFont(size: 16, weight: .semibold)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            content()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Шапка

    /// «Привет, имя!», серия дней и сколько новых слов из нормы сегодня; нажатие — профиль
    private var header: some View {
        let profile = profiles.first
        return Button {
            Haptics.tap()
            openProfile()
        } label: {
            HStack(spacing: 14) {
                avatar(profile)
                // Слева — приветствие и рекорд Тетриса, справа столбиком — серия дней и норма слов
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Привет, \(profile?.name ?? "Студент")!")
                            .scaledFont(size: 20, weight: .bold)
                            .foregroundColor(.brandDark)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("🎮 \((profile?.tetrisHighScore ?? 0).formatted()) \(Self.pointsNoun(profile?.tetrisHighScore ?? 0))")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(.brandDark.opacity(0.75))
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("🔥 \(streak) \(Self.daysNoun(streak))")
                        Text(dailyLimit > 0 ? "🎯 \(introducedToday)/\(dailyLimit) слов" : "🎯 \(introducedToday) \(DailyStudyCard.wordsNoun(introducedToday))")
                    }
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundColor(.brandDark.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            // Плашка на всю ширину: уходит под статус-бар, внизу скруглена
            .background(alignment: .bottom) {
                UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
                    .fill(Color.cardBackground)
                    .padding(.top, -300)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Привет, \(profile?.name ?? "Студент"). Рекорд Тетриса \(profile?.tetrisHighScore ?? 0). Серия \(streak) \(Self.daysNoun(streak)), сегодня \(introducedToday) из \(dailyLimit) слов. Открыть профиль")
    }

    private func avatar(_ profile: UserProfile?) -> some View {
        ZStack {
            Circle().fill(Color.teal.opacity(0.18))
            if let data = profile?.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.teal)
            }
        }
        .frame(width: 58, height: 58)
    }

    /// 1 очко, 2 очка, 5 очков
    private static func pointsNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "очков" }
        switch last {
        case 1: return "очко"
        case 2...4: return "очка"
        default: return "очков"
        }
    }

    /// 1 день, 2 дня, 5 дней
    private static func daysNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "дней" }
        switch last {
        case 1: return "день"
        case 2...4: return "дня"
        default: return "дней"
        }
    }

    // MARK: - Быстрый доступ

    private var quickAccess: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(layout.quickAccess, id: \.self) { section in
                QuickAccessTile(section: section) { open(section.screen) }
            }
        }
    }

    // MARK: - Подборки

    private var collections: some View {
        VStack(spacing: 10) {
            ForEach(savedTopics.prefix(Self.collectionsShown)) { topic in
                SavedTopicRow(topic: topic) { open(.topic(topic)) }
            }
        }
    }
}

// MARK: - Фокус дня

/// Главное занятие одной кнопкой. Для «Карточек для запоминания» — интервальное повторение:
/// сколько слов пора повторить и полоска дневной нормы новых слов
private struct FocusCard: View {
    let section: MenuSection
    let dueCount: Int
    let introducedToday: Int
    let dailyLimit: Int
    let action: () -> Void

    private var isSpacedRepetition: Bool { section == .flashcards }

    var body: some View {
        // Строки у всех карточек карусели на одних и тех же местах, как у «Интервального повторения»:
        // промежутки по 14, название и подпись — в одну строку (подпись не влезла — «…»), место под норму новых слов есть у всех
        VStack(alignment: .leading, spacing: 14) {
            Label("Фокус дня".uppercased(), systemImage: "sparkles")
                .scaledFont(size: 14, weight: .bold)
                .foregroundColor(.orange)
            Text(isSpacedRepetition ? "Интервальное повторение" : section.title)
                .scaledFont(size: 24, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .scaledFont(size: 15)
                .foregroundColor(.gray)
                .lineLimit(1)
                .truncationMode(.tail)
            Button {
                Haptics.tap()
                action()
            } label: {
                Label(isSpacedRepetition ? "Начать повторение" : "Начать", systemImage: "play.fill")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            // Норма новых слов — только у интервального повторения; у остальных на её месте пусто
            newWordsProgress
                .opacity(isSpacedRepetition && dailyLimit > 0 ? 1 : 0)
                .accessibilityHidden(!(isSpacedRepetition && dailyLimit > 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var newWordsProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(min(introducedToday, max(dailyLimit, 1))), total: Double(max(dailyLimit, 1)))
                .tint(.orange)
            Text("Новые слова сегодня: \(introducedToday) из \(dailyLimit)")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
        }
    }

    private var subtitle: String {
        guard isSpacedRepetition else { return section.focusHint }
        return dueCount > 0
            ? "Пора повторить: \(dueCount) \(DailyStudyCard.wordsNoun(dueCount))"
            : "Повторять пока нечего — можно взять новые слова"
    }
}

// MARK: - Плитки и строки

/// Плитка «Быстрого доступа»: иконка раздела и название в две строки
private struct QuickAccessTile: View {
    let section: MenuSection
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .scaledFont(size: 20, weight: .semibold)
                    .foregroundColor(section.color)
                    .frame(width: 28)
                Text(section.title)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Подборка из «Сообщества»: название и число слов
struct SavedTopicRow: View {
    let topic: CommunityTopic
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "text.book.closed.fill")
                    .scaledFont(size: 22)
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.brandDark)
                        .lineLimit(1)
                    Text([topic.words.isEmpty ? topic.section : "\(topic.words.count) \(DailyStudyCard.wordsNoun(topic.words.count))",
                          topic.ratingSummary].filter { !$0.isEmpty }.joined(separator: " · "))
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
