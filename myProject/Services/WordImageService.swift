import Foundation
import UIKit

// Ищет картинку к английскому слову без API-ключей:
// сначала Википедия (точна для предметов), затем Openverse (любые слова)
enum WordImageService {
    enum Result {
        case found(Data)
        case notFound
        case failed   // нет сети или сервис недоступен — можно попробовать позже
    }

    private static let userAgent = "WordLearner/1.0 (iOS)"
    private static let maxPixelSize: CGFloat = 400

    static func fetchImage(for word: String, variant: Int) async -> Result {
        let query = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return .notFound }

        let candidates: [URL]
        do {
            candidates = try await candidateURLs(for: query)
        } catch {
            return .failed
        }
        guard !candidates.isEmpty else { return .notFound }

        // Начинаем с нужного варианта и идём дальше, если картинка не скачалась
        for offset in 0..<candidates.count {
            let url = candidates[(variant + offset) % candidates.count]
            if let data = try? await downloadThumbnail(from: url) {
                return .found(data)
            }
        }
        return .failed
    }

    // MARK: - Поиск кандидатов

    private static func candidateURLs(for query: String) async throws -> [URL] {
        var urls: [URL] = []
        // Ошибка одного источника не должна мешать второму
        if let wiki = try? await wikipediaThumbnail(for: query) {
            urls.append(wiki)
        }
        do {
            urls += try await openverseThumbnails(for: query)
        } catch where urls.isEmpty {
            throw error
        }
        return urls
    }

    private struct WikiSummary: Decodable {
        struct Thumbnail: Decodable { let source: URL }
        let type: String
        let thumbnail: Thumbnail?
    }

    private static func wikipediaThumbnail(for query: String) async throws -> URL? {
        let title = query.replacingOccurrences(of: " ", with: "_")
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }
        let summary: WikiSummary = try await fetchJSON(from: url)
        // Страницы-неоднозначности ("run", "bank") дают случайную картинку
        guard summary.type == "standard" else { return nil }
        return summary.thumbnail?.source
    }

    private struct OpenverseResponse: Decodable {
        struct Item: Decodable { let thumbnail: URL? }
        let results: [Item]
    }

    private static func openverseThumbnails(for query: String) async throws -> [URL] {
        var components = URLComponents(string: "https://api.openverse.org/v1/images/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: "10"),
            URLQueryItem(name: "license_type", value: "commercial"),
            URLQueryItem(name: "mature", value: "false")
        ]
        guard let url = components?.url else { return [] }
        let response: OpenverseResponse = try await fetchJSON(from: url)
        return response.results.compactMap(\.thumbnail)
    }

    // MARK: - Сеть

    private static func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func downloadThumbnail(from url: URL) async throws -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let image = UIImage(data: data) else { return nil }

        // Уменьшаем до разумного размера, чтобы не раздувать базу
        let scale = min(1, maxPixelSize / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = await image.byPreparingThumbnail(ofSize: targetSize) ?? image
        return resized.jpegData(compressionQuality: 0.7)
    }
}
