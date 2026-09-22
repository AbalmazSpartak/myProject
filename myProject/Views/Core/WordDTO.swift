import Foundation

struct WordDTO: Decodable {
    let english: String
    let russian: String
    let transcription: String
    let example: String
    let categoryName: String
}
