import SwiftUI

/// Бегунок скорости речи с 10 точками на шкале (без цифр): левая точка — самая медленная речь, правая — самая быстрая
struct SpeechRateSlider: View {
    @Binding var rate: Double
    var title = "Скорость речи"

    private static let points = 10
    private static let lower = SpeechSettings.rateRange.lowerBound
    private static let step = (SpeechSettings.rateRange.upperBound - lower) / Double(points - 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            HStack(spacing: 8) {
                Image(systemName: "tortoise.fill").foregroundColor(.gray)
                Slider(value: $rate, in: SpeechSettings.rateRange, step: Self.step) {
                    Text(title)
                }
                .overlay { dots }
                Image(systemName: "hare.fill").foregroundColor(.gray)
            }
            // Место под точки, которые лежат под ползунком
            .padding(.bottom, 14)
        }
        .padding(.vertical, 4)
        // Прежнее значение между точками — на ближайшую, чтобы ползунок стоял ровно на шкале
        .onAppear {
            let snapped = Self.lower + ((rate - Self.lower) / Self.step).rounded() * Self.step
            if abs(snapped - rate) > 0.0001 { rate = snapped }
        }
    }

    /// Точки по длине дорожки; ползунок у края не доходит на свою половину ширины
    private var dots: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 14
            let span = proxy.size.width - inset * 2
            ForEach(0..<Self.points, id: \.self) { index in
                Circle()
                    .fill(Color.gray.opacity(0.55))
                    .frame(width: 4, height: 4)
                    .position(x: inset + span * CGFloat(index) / CGFloat(Self.points - 1),
                              y: proxy.size.height / 2 + 18)
            }
        }
        .allowsHitTesting(false)
    }
}
