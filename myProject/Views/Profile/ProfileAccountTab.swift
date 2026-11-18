import SwiftUI
import SwiftData

/// Вкладка «Аккаунт» профиля по макету «22 · Профиль»: карточка аккаунта, блок текущего режима (по переключателю сверху),
/// «Общее» и выход. Цифры успехов вынесены на вкладку «Статистика»
struct ProfileAccountTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    @AppStorage("app_theme") private var theme = "system"
    @State private var account = Account.shared
    /// Блок режима — по переключателю сверху, без своих вкладок: один переключатель на экране
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @State private var showSettings = false
    @State private var askSignOut = false
    @State private var openedBook: Book?

    private var profile: UserProfile { profiles.first ?? UserProfile.ensureSingle(in: modelContext) }

    private var currentBook: Book? {
        books.filter { $0.lastOpenedAt != nil }.max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch mode {
            case .reading: readingPart
            case .learning: learningPart
            }
            header("Общее")
            general
            if account.isSignedIn { signOutButton }
        }
        .navigationDestination(item: $openedBook) { book in
            BookDetailView(book: book).toolbar(.hidden, for: .tabBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(profile: profile).appThemedColorScheme()
        }
        .confirmationDialog("Выйти из аккаунта?", isPresented: $askSignOut, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) { Task { await account.signOut() } }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Слова и книги останутся на этом устройстве.")
        }
    }

    // MARK: Блок режима

    private var readingPart: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let book = currentBook {
                HStack(alignment: .top, spacing: 14) {
                    BookCoverThumb(book: book)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Сейчас читаю").scaledFont(size: 12, weight: .semibold).foregroundColor(.brandMuted).textCase(.uppercase)
                        Text(book.title).scaledFont(size: 19, weight: .semibold, design: .serif).foregroundColor(.brandDark).lineLimit(2)
                        Text(book.author).scaledFont(size: 13).foregroundColor(.brandMuted).lineLimit(1)
                        ProgressView(value: book.progress).tint(.brandTint).padding(.top, 6)
                        Button { openedBook = book } label: {
                            Text("Продолжить")
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundColor(.brandOnTint)
                                .padding(.horizontal, 18).frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandTint))
                        }
                        .padding(.top, 6)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .card()
            }
            VStack(spacing: 0) {
                row("bookmark", "Закладки", value: "скоро", showsChevron: false)
                divider
                row("note.text", "Заметки", value: "скоро", showsChevron: false)
            }
            .card()
            header("Читалка и озвучка")
            VStack(spacing: 0) {
                NavigationLink { SpeechSettingsView(mode: .reading) } label: { row("speaker.wave.2", "Озвучка и голос") }
                divider
                Button { showSettings = true } label: { row("textformat.size", "Шрифт, размер и страница") }
            }
            .buttonStyle(.plain)
            .card()
        }
    }

    private var learningPart: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                NavigationLink { LearningSettingsView() } label: { row("arrow.triangle.2.circlepath", "Повторение и карточки") }
                divider
                NavigationLink { SpeechSettingsView(mode: .learning) } label: { row("mic", "Произношение и озвучка") }
                divider
                Button { showSettings = true } label: { row("bell", "Тихое напоминание", value: "в Настройках") }
            }
            .buttonStyle(.plain)
            .card()
            VStack(spacing: 0) {
                row("folder", "Свои темы", value: "скоро", showsChevron: false)
            }
            .card()
        }
    }

    // MARK: Общее

    private var general: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "moon").scaledFont(size: 20).foregroundColor(.brandTint).frame(width: 26)
                Text("Тема").scaledFont(size: 15).foregroundColor(.brandDark)
                Spacer()
                Picker("Тема", selection: $theme) {
                    Text("Как в системе").tag("system")
                    Text("Светлая").tag("light")
                    Text("Тёмная").tag("dark")
                }
                .tint(.brandMuted)
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            divider
            NavigationLink { AccountView() } label: {
                row("arrow.triangle.2.circlepath.icloud", "Синхронизация", value: account.isSignedIn ? "Включена" : "Войдите")
            }
            divider
            Button { showSettings = true } label: { row("gearshape", "Все настройки") }
        }
        .buttonStyle(.plain)
        .card()
    }

    private var signOutButton: some View {
        Button { askSignOut = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Выйти из аккаунта").scaledFont(size: 15, weight: .semibold)
            }
            .foregroundColor(.brandDark)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Мелочи

    private func header(_ title: String) -> some View {
        Text(title).scaledFont(size: 12, weight: .semibold).foregroundColor(.brandMuted).textCase(.uppercase)
            .padding(.horizontal, 4).padding(.top, 6)
    }

    private var divider: some View { Divider().overlay(Color.brandBorder) }

    private func row(_ icon: String, _ title: String, value: String? = nil, showsChevron: Bool = true) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).scaledFont(size: 20).foregroundColor(.brandTint).frame(width: 26)
            Text(title).scaledFont(size: 15).foregroundColor(.brandDark)
            Spacer(minLength: 8)
            if let value { Text(value).scaledFont(size: 13).foregroundColor(.brandMuted) }
            if showsChevron { Image(systemName: "chevron.right").scaledFont(size: 13, weight: .semibold).foregroundColor(.brandMuted) }
        }
        .padding(.horizontal, 16).frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// Обложка книги для карточки «Сейчас читаю»
private struct BookCoverThumb: View {
    let book: Book
    var body: some View {
        Group {
            if let data = book.coverData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.brandAccent.overlay(
                    Text(book.title).scaledFont(size: 12, design: .serif).foregroundColor(.brandTint).padding(6),
                    alignment: .bottomLeading)
            }
        }
        .frame(width: 72, height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private extension View {
    func card() -> some View {
        background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
    }
}

/// Карточка аккаунта наверху профиля (аватар, имя, почта, «Изменить» и «Аккаунт») — над вкладками «Аккаунт | Статистика»
struct ProfileHeaderCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var account = Account.shared
    @State private var showPersonalData = false

    private var profile: UserProfile { profiles.first ?? UserProfile.ensureSingle(in: modelContext) }

    var body: some View {
        accountCard
            .sheet(isPresented: $showPersonalData) {
                PersonalDataView(profile: profile).appThemedColorScheme()
            }
    }

    private var accountCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).scaledFont(size: 18, weight: .semibold).foregroundColor(.brandDark).lineLimit(1)
                    Text(account.email ?? "Вход не выполнен")
                        .scaledFont(size: 13).foregroundColor(.brandMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button { showPersonalData = true } label: { outlined("Изменить", "pencil") }
                NavigationLink { AccountView() } label: { outlined("Аккаунт", "person") }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .card()
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = profile.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 60, height: 60).clipShape(Circle())
        } else {
            Text(String(profile.name.prefix(1)).uppercased())
                .scaledFont(size: 26, weight: .semibold, design: .serif)
                .foregroundColor(.brandTint)
                .frame(width: 60, height: 60)
                .background(Color.brandAccent, in: Circle())
        }
    }

    private func outlined(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).scaledFont(size: 15)
            Text(title).scaledFont(size: 14, weight: .medium)
        }
        .foregroundColor(.brandDark)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandBorder, lineWidth: 1.5))
    }

}
