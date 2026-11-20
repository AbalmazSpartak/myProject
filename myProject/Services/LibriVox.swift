import Foundation

/// Живые аудиокниги LibriVox: классику читают вслух люди-волонтёры, записи — общественное достояние.
/// Открытый API без ключей; mp3 лежат на archive.org. Сервер отвечает медленно (секунды), поэтому популярные книги — готовым списком
nonisolated enum LibriVox {
    struct Section: Codable, Hashable, Sendable, Identifiable {
        let number: Int
        let title: String
        let url: URL
        let seconds: Int
        let reader: String
        var id: Int { number }
    }

    struct Audiobook: Codable, Hashable, Sendable, Identifiable {
        let id: Int
        let title: String
        let author: String
        /// Та же книга в Project Gutenberg — оттуда берётся текст
        let gutenbergID: Int?
        /// Папка записи на archive.org — по ней обложка
        let archiveID: String?
        let seconds: Int
        /// Кто читает (для списка без глав — из готового списка)
        var readerNames: [String]
        var sections: [Section]

        var coverURL: URL? { archiveID.flatMap { URL(string: "https://archive.org/services/img/\($0)") } }

        var readers: [String] {
            var seen = Set<String>()
            let names = sections.isEmpty ? readerNames : sections.map(\.reader)
            return names.filter { !$0.isEmpty && seen.insert($0).inserted }
        }

        /// Кто читает — для подписи: один чтец по имени, иначе «N чтецов»
        var readerText: String {
            let names = readers
            switch names.count {
            case 0: return ""
            case 1: return "читает \(names[0])"
            default: return "читают \(names.count) чтецов"
            }
        }

        /// mp3 64 кбит/с: 8 000 байт в секунду
        var estimatedBytes: Int64 { Int64(seconds) * 8_000 }
    }

    private static let userAgent = "LexiStream/1.0 (iOS)"
    private static let base = "https://librivox.org/api/feed/audiobooks/"

    // MARK: - Популярное

    /// Подобрано заранее: английская классика с текстом в Gutenberg, читает один человек (так легче слушать ученику)
    static let featured: [Audiobook] = [
        item(900, "Alice's Adventures in Wonderland", "Lewis Carroll", 11, "alice_wonderland_0711_librivox", 9780),
        item(448, "The Adventures of Tom Sawyer", "Mark Twain", 74, "tom_sawyer_librivox", 24360),
        item(59, "Adventures of Huckleberry Finn", "Mark Twain", 76, "huck_finn_librivox", 38527),
        item(4135, "The Adventures of Sherlock Holmes", "Arthur Conan Doyle", 1661, "adventures_sherlock_holmes_rg_librivox", 48540),
        item(901, "The Hound of the Baskervilles", "Arthur Conan Doyle", 2852, "hound_baskervilles_librivox", 21120),
        item(1557, "Treasure Island", "Robert Louis Stevenson", 120, "treasure_island_ap_librivox", 27120),
        item(662, "The Jungle Book", "Rudyard Kipling", 236, "jungle_book_mh_0808_librivox", 18120),
        item(11993, "Peter Pan", "J. M. Barrie", 16, "peterpan_1706_librivox", 19329),
        item(332, "The Wonderful Wizard of Oz", "L. Frank Baum", 55, "wizard_of_oz", 13440),
        item(685, "A Christmas Carol", "Charles Dickens", 46, "christmascarol_librivox", 9780),
        item(365, "The Picture of Dorian Gray", "Oscar Wilde", 4078, "dorian_gray_librivox", 22260),
        item(5668, "Frankenstein", "Mary Shelley", 84, "frankenstein_1107_librivox", 26760),
        item(10747, "Dracula", "Bram Stoker", 345, "dracula_ks_1608_librivox", 57480),
        item(5618, "The Time Machine", "H. G. Wells", 35, "timemachine_sjm_librivox", 13140),
        item(552, "The War of the Worlds", "H. G. Wells", 36, "war_worlds_solo_librivox", 23700),
        item(3550, "Black Beauty", "Anna Sewell", 271, "blackbeauty_0910_librivox", 20520),
        item(56, "The Secret Garden", "Frances Hodgson Burnett", 113, "secret_garden_librivox", 32880),
        item(175, "A Little Princess", "Frances Hodgson Burnett", 146, "littleprincess_librivox", 27300),
        item(318, "Anne of Green Gables", "Lucy Maud Montgomery", 45, "anne_gables_0808", 39120),
        item(4480, "The Call of the Wild", "Jack London", 215, "callofthewild_tc_1010_librivox", 12840),
        item(4677, "White Fang", "Jack London", 910, "whitefang2_1010_librivox", 27780),
        item(417, "Strange Case of Dr Jekyll and Mr Hyde", "Robert Louis Stevenson", 43, "jekyll_and_hyde_librivox", 11280),
        item(19251, "The Great Gatsby", "F. Scott Fitzgerald", 64317, "great_gatsby_2305_librivox", 17820),
        item(254, "Pride and Prejudice", "Jane Austen", 1342, "solo_pride_librivox", 48300),
        item(86, "Emma", "Jane Austen", 158, "emma_solo_librivox", 64920),
        item(2192, "Jane Eyre", "Charlotte Brontë", 1260, "jane_eyre_ver03_0809_librivox", 66960),
        item(7143, "Little Women", "Louisa May Alcott", 37106, "little_women_1212_librivox", 70680),
        item(696, "Robinson Crusoe", "Daniel Defoe", 521, "robinson_crusoe_librivox", 50100),
        item(693, "Gulliver's Travels", "Jonathan Swift", 829, "gulliver_ld_librivox", 40200),
    ]

    private static func item(_ id: Int, _ title: String, _ author: String, _ gutenberg: Int, _ archive: String, _ seconds: Int) -> Audiobook {
        Audiobook(id: id, title: title, author: author, gutenbergID: gutenberg, archiveID: archive,
                  seconds: seconds, readerNames: [], sections: [])
    }

    // MARK: - Запросы

    /// Полная запись с главами
    static func details(id: Int) async throws -> Audiobook? {
        try await request(["id": "\(id)"]).first
    }

    /// Поиск по началу названия (без The/A) и по фамилии автора; только английские записи с текстом в Gutenberg
    static func search(_ query: String) async throws -> [Audiobook] {
        let title = titlePrefix(query)
        let surname = query.split(separator: " ").last.map(String.init) ?? query
        guard !title.isEmpty else { return [] }
        async let byTitle = (try? request(["title": "^" + title])) ?? []
        async let byAuthor = (try? request(["author": surname])) ?? []
        var seen = Set<Int>()
        return (await byTitle + byAuthor).filter { seen.insert($0.id).inserted }
    }

    /// Записи этой книги Gutenberg: сначала те, где читает один человек
    static func recordings(gutenbergID: Int, title: String) async throws -> [Audiobook] {
        let prefix = titlePrefix(title)
        guard !prefix.isEmpty else { return [] }
        return try await request(["title": "^" + prefix])
            .filter { $0.gutenbergID == gutenbergID }
            .sorted { ($0.readers.count, $0.id) < ($1.readers.count, $1.id) }
    }

    /// LibriVox хранит названия без артикля и ищет по началу: «The Adventures of…» → «Adventures of», подзаголовок отрезаем
    static func titlePrefix(_ text: String) -> String {
        var title = text.replacingOccurrences(of: "’", with: "'")
        if let cut = title.firstIndex(where: { ":;(—\n".contains($0) }) { title = String(title[..<cut]) }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        for article in ["the ", "a ", "an "] where title.lowercased().hasPrefix(article) {
            title = String(title.dropFirst(article.count))
        }
        // Длинные названия пишутся по-разному — хватит первых четырёх слов
        return title.split(separator: " ").prefix(4).joined(separator: " ")
    }

    private static func request(_ parameters: [String: String]) async throws -> [Audiobook] {
        var components = URLComponents(string: base)
        components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "extended", value: "1"),
               URLQueryItem(name: "limit", value: "30")]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        // «Ничего не нашлось» сервер отдаёт ошибкой 404 с {"error": …}
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return [] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let books = json["books"] as? [[String: Any]] else { return [] }
        return books.compactMap(parse)
    }

    private static func parse(_ raw: [String: Any]) -> Audiobook? {
        guard let id = int(raw["id"]), let title = raw["title"] as? String,
              (raw["language"] as? String) == "English" else { return nil }
        let source = raw["url_text_source"] as? String ?? ""
        let gutenberg = source.firstMatch(of: /gutenberg\.org\/(?:etext|ebooks|files)\/(\d+)/).flatMap { Int($0.1) }
        guard gutenberg != nil else { return nil }
        let authors = (raw["authors"] as? [[String: Any]] ?? []).map {
            "\($0["first_name"] as? String ?? "") \($0["last_name"] as? String ?? "")".trimmingCharacters(in: .whitespaces)
        }
        let archive = (raw["url_iarchive"] as? String)?.split(separator: "/").last.map(String.init)
        let sections: [Section] = (raw["sections"] as? [[String: Any]] ?? []).compactMap { section in
            guard let number = int(section["section_number"]),
                  let link = section["listen_url"] as? String, !link.isEmpty,
                  let url = URL(string: link.replacingOccurrences(of: "http://", with: "https://")) else { return nil }
            let reader = ((section["readers"] as? [[String: Any]])?.first?["display_name"] as? String) ?? ""
            return Section(number: number, title: section["title"] as? String ?? "Часть \(number)", url: url,
                           seconds: int(section["playtime"]) ?? 0, reader: reader)
        }
        .sorted { $0.number < $1.number }
        guard !sections.isEmpty else { return nil }
        let cleanTitle = title.replacing(/\s*\((?i:version)[^)]*\)/, with: "")
        return Audiobook(id: id, title: cleanTitle, author: authors.joined(separator: ", "), gutenbergID: gutenberg,
                         archiveID: archive, seconds: int(raw["totaltimesecs"]) ?? sections.reduce(0) { $0 + $1.seconds },
                         readerNames: [], sections: sections)
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let text = value as? String { return Int(text) }
        return nil
    }

    /// «10 ч 42 мин»
    static func durationText(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded())
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(max(rest, 1)) мин" }
        return rest == 0 ? "\(hours) ч" : "\(hours) ч \(rest) мин"
    }
}
