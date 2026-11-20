import Foundation
import Testing
@testable import Loe

struct LoeProjectTests {
    private static let forms = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: ".github/ISSUE_TEMPLATE")

    /// About sends readers to GitHub to report a problem, where a blank box would
    /// ask them nothing.
    @Test func reportingAProblemOpensTheFormsThisRepositoryKeeps() throws {
        #expect(LoeProject.issues.absoluteString == LoeProject.repository.absoluteString + "/issues/new/choose")
        let config = try String(contentsOf: Self.forms.appending(path: "config.yml"), encoding: .utf8)
        #expect(config.contains("blank_issues_enabled: false"))
        let forms = try FileManager.default.contentsOfDirectory(atPath: Self.forms.path)
            .filter { $0.hasSuffix(".yml") && $0 != "config.yml" }
        #expect(forms.sorted() == ["book_data.yml", "bug_report.yml", "idea.yml"])
        for form in forms {
            let text = try String(contentsOf: Self.forms.appending(path: form), encoding: .utf8)
            #expect(text.hasPrefix("name: "), "\(form)")
            #expect(text.contains("\nbody:\n"), "\(form)")
        }
    }
}
