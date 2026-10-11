import Foundation
import SwiftData

/// Комментарий в обсуждении темы «Сообщества». Ответы — один уровень: `parentID` — id комментария верхнего уровня.
/// Пока хранится только на этом телефоне; с общими темами (CloudKit) появятся чужие комментарии и общие «нравится»
@Model
final class TopicComment {
    var id: UUID = UUID()
    var text: String
    /// Имя автора на момент отправки
    var authorName: String
    var createdAt: Date = Date()
    var editedAt: Date?
    /// Ответ на комментарий верхнего уровня; nil — сам верхнего уровня
    var parentID: UUID?
    /// Написал этот пользователь — ему можно править и удалять
    var isMine = true
    /// «Нравится» от этого пользователя и от остальных (пока остальных нет — 0)
    var isLikedByMe = false
    var othersLikeCount = 0
    var topic: CommunityTopic?

    init(text: String, authorName: String, parentID: UUID? = nil) {
        self.text = text
        self.authorName = authorName
        self.parentID = parentID
    }

    var likeCount: Int { othersLikeCount + (isLikedByMe ? 1 : 0) }
}
