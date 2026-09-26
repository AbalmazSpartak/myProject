import Foundation

struct FSRSCalculator {
    // Стандартные веса FSRS v4, оптимизированные на миллионах логов
    private let w: [Double] = [
        0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01,
        1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61
    ]
    
    private let targetRetention = 0.9 // Целевой процент запоминания (90%)

    func calculateNextReview(word: Word, rating: FSRSRating) {
        let now = Date()
        let lastRev = word.lastReview ?? now
        let daysElapsed = max(0, now.timeIntervalSince(lastRev) / 86400.0)
        
        var newDifficulty = word.difficulty
        var newStability = word.stability
        var newState = word.state
        
        if word.state == .new {
            // Инициализация нового слова
            newDifficulty = initDifficulty(rating: rating)
            newStability = initStability(rating: rating)
            newState = (rating == .again) ? .learning : .review
        } else {
            // Обновление существующего слова
            let retrievability = exp(log(0.9) * daysElapsed / word.stability)
            newDifficulty = nextDifficulty(d: word.difficulty, rating: rating)
            
            if rating == .again {
                newStability = nextForgetStability(d: newDifficulty, s: word.stability, r: retrievability)
                newState = .relearning
                word.lapses += 1
            } else {
                newStability = nextRecallStability(d: newDifficulty, s: word.stability, r: retrievability, rating: rating)
                newState = .review
            }
        }
        
        // Расчет следующего интервала (в днях)
        let interval = newStability * (pow(targetRetention, -1) - 1) * 9
        
        // Применяем изменения к слову
        word.difficulty = newDifficulty
        word.stability = newStability
        word.state = newState
        word.reps += 1
        word.lastReview = now
        
        // Устанавливаем дату следующего повторения (если "Снова", то через 5 минут)
        if rating == .again {
            word.dueDate = now.addingTimeInterval(5 * 60) // 5 минут для забытых
        } else {
            word.dueDate = now.addingTimeInterval(interval * 86400) // В днях
        }
    }
    
    // MARK: - Внутренние математические функции FSRS
    private func initStability(rating: FSRSRating) -> Double {
        return w[rating.rawValue - 1]
    }
    
    private func initDifficulty(rating: FSRSRating) -> Double {
        return min(max(w[4] - w[5] * Double(rating.rawValue - 3), 1.0), 10.0)
    }
    
    private func nextDifficulty(d: Double, rating: FSRSRating) -> Double {
        let nextD = d - w[6] * Double(rating.rawValue - 3)
        return min(max(nextD, 1.0), 10.0)
    }
    
    private func nextRecallStability(d: Double, s: Double, r: Double, rating: FSRSRating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1.0
        let easyBonus = rating == .easy ? w[16] : 1.0
        
        let sInc = exp(w[8]) *
            (11.0 - d) *
            pow(s, -w[9]) *
            (exp((1.0 - r) * w[10]) - 1.0) *
            hardPenalty * easyBonus
        
        return s * (1.0 + sInc)
    }
    
    private func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        return w[11] * pow(d, -w[12]) * pow(s + 1.0, w[13]) * exp((1.0 - r) * w[14])
    }
}
