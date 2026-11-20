import Testing
@testable import Loe

@MainActor
struct SnapshotTests {
    @Test func aRenderThatFailsIsTriedAgain() {
        var goes = 0
        let value = Snapshot.firstSuccess(in: 3) {
            goes += 1
            return goes < 3 ? nil : "rendered"
        }
        #expect(value == "rendered")
        #expect(goes == 3)
    }

    @Test func aRenderThatWorksIsNotRepeated() {
        var goes = 0
        let value = Snapshot.firstSuccess(in: 3) {
            goes += 1
            return "rendered"
        }
        #expect(value == "rendered")
        #expect(goes == 1)
    }

    @Test func aRenderThatNeverWorksGivesUp() {
        var goes = 0
        let value: String? = Snapshot.firstSuccess(in: 3) {
            goes += 1
            return nil
        }
        #expect(value == nil)
        #expect(goes == 3)
    }
}
