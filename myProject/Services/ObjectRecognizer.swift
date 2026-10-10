import Foundation
import Vision

/// Догадка о предмете на фото: английское слово и уверенность распознавателя (0…1)
nonisolated struct ObjectGuess: Identifiable, Hashable, Sendable {
    let english: String
    let confidence: Float

    var id: String { english }
    var isConfident: Bool { confidence >= 0.5 }
}

/// Что на фото: встроенный распознаватель iOS (около 1300 предметов и сцен), на устройстве, без интернета
nonisolated enum ObjectRecognizer {
    private static let minConfidence: Float = 0.1
    private static let maxGuesses = 5

    /// Самые уверенные догадки без повторов: сначала конкретные предметы, потом общие категории.
    /// Категория получает ту же уверенность, что и предмет внутри неё (mug 0.77 → tableware 0.86), — иначе была бы первой
    static func guesses(in imageData: Data) async throws -> [ObjectGuess] {
        let observations = try await ClassifyImageRequest().perform(on: imageData)
        var seen = Set<String>()
        var result: [ObjectGuess] = []
        for observation in observations.sorted(by: { $0.confidence > $1.confidence }) where observation.confidence >= minConfidence {
            guard let english = word(for: observation.identifier), seen.insert(english).inserted else { continue }
            result.append(ObjectGuess(english: english, confidence: observation.confidence))
        }
        let specific = result.filter { !categories.contains($0.english) }
        let general = result.filter { categories.contains($0.english) }
        return Array((specific + general).prefix(maxGuesses))
    }

    /// Общие категории: остаются в вариантах, но после конкретных предметов
    private static let categories: Set<String> = [
        "art", "illustrations", "animal", "mammal", "bird", "reptile", "insect", "fish", "plant", "foliage", "food",
        "fruit", "vegetable", "drink", "beverage", "dessert", "baked goods", "tableware", "utensil", "cookware",
        "furniture", "container", "clothing", "headwear", "accessory", "jewelry", "vehicle", "tool", "equipment",
        "appliance", "decoration", "musical instrument", "sports equipment", "building", "room", "toy", "office supplies"
    ]

    /// Метка распознавателя → обычное слово: kitchen_room → kitchen, cardboard_box → box; слишком общие — nil
    static func word(for identifier: String) -> String? {
        guard !skipped.contains(identifier) else { return nil }
        return replacements[identifier] ?? identifier.replacingOccurrences(of: "_", with: " ")
    }

    /// Слишком общие метки: учить их по фото незачем
    private static let skipped: Set<String> = [
        "adult", "people", "outdoor", "structure", "material", "textile", "conveyance", "consumer_electronics",
        "document", "games", "recreation", "land", "liquid", "machine", "celestial_body", "celestial_body_other",
        "interior_room", "interior_shop", "polka_dots", "sunset_sunrise"
    ]

    /// Метки с уточнением в названии и метки, для которых в жизни говорят другое слово
    private static let replacements: [String: String] = [
        "adult_cat": "cat", "alligator_crocodile": "crocodile", "basket_container": "basket", "bathroom_faucet": "faucet",
        "bathroom_room": "bathroom", "cake_regular": "cake", "candy_other": "candy", "chair_other": "chair",
        "glove_other": "glove", "road_other": "road", "snake_other": "snake", "cardboard_box": "box", "carton": "box",
        "coyote_wolf": "wolf", "crane_construction": "crane", "drone_machine": "drone", "engine_vehicle": "engine",
        "house_single": "house", "iron_clothing": "iron", "kitchen_room": "kitchen", "kitchen_faucet": "faucet",
        "pepper_veggie": "pepper", "pot_cooking": "pot", "organ_instrument": "organ", "play_card": "playing card",
        "raw_glass": "glass", "drinking_glass": "glass", "shellfish_prepared": "shellfish", "slide_toy": "slide",
        "speakers_music": "speaker", "squash_sport": "squash", "steamer_cookware": "steamer", "straw_drinking": "straw",
        "straw_hay": "straw", "submarine_water": "submarine", "swing_playground": "swing", "tea_drink": "tea",
        "train_real": "train", "train_toy": "toy train", "water_body": "water", "wood_natural": "wood",
        "wood_processed": "wood", "balloon_hotair": "hot-air balloon", "cricket_sport": "cricket", "fencing_sport": "fencing",
        "track_rail": "railway", "monitor_lizard": "lizard", "computer_keyboard": "keyboard", "computer_mouse": "mouse",
        "computer_monitor": "monitor", "computer_tower": "computer", "footwear": "shoe", "eyeglasses": "glasses",
        "automobile": "car", "portal": "door", "trash_can": "trash can", "light_bulb": "light bulb", "electric_fan": "fan",
        "kitchen_oven": "oven", "kitchen_sink": "sink", "toaster_oven": "toaster", "laundry_machine": "washing machine",
        "weight_scale": "scales", "wine_bottle": "bottle", "board_game": "board game", "stuffed_animals": "soft toy",
        "vehicle_toy": "toy car", "musical_instrument": "musical instrument", "string_instrument": "musical instrument",
        "office_supplies": "stationery", "printed_page": "page", "sports_equipment": "sports equipment"
    ]
}
