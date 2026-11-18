import SwiftUI

/// One to five stars in Rukis. With `onRate`, tapping a star sets the rating and
/// tapping the current one clears it.
struct RatingStars: View {
    let rating: Int?
    var size: CGFloat = 22
    var onRate: ((Int?) -> Void)?

    var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(.loeRating)
                    .contentShape(.rect)
                    .onTapGesture {
                        onRate?(star == rating ? nil : star)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating"))
        .accessibilityValue(rating.map { Text("\($0) of 5 stars") } ?? Text("Not rated"))
        .accessibilityAdjustableAction { direction in
            guard let onRate else { return }
            switch direction {
            case .increment: onRate(min((rating ?? 0) + 1, 5))
            case .decrement: onRate((rating ?? 0) <= 1 ? nil : (rating ?? 0) - 1)
            @unknown default: break
            }
        }
    }
}
