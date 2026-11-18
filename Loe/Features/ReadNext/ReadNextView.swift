import SwiftUI

struct ReadNextView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Nothing to suggest yet", systemImage: "sparkles")
            } description: {
                Text("Rate a few books and Loe will suggest what to read next.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.loeBackground)
            .navigationTitle("Read next")
        }
    }
}

#Preview {
    ReadNextView()
}
