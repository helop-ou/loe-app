import SwiftUI

struct ReadNextView: View {
    var body: some View {
        NavigationStack {
            EmptyState(
                title: "Nothing to suggest yet",
                systemImage: "sparkles",
                description: "Rate a few books and Loe will suggest what to read next."
            )
            .navigationTitle("Read next")
        }
    }
}

#Preview {
    ReadNextView()
}
