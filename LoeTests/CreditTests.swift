import Foundation
import Testing
@testable import Loe

struct CreditTests {
    @Test func everyLicenceShippedIsCreditedAndReadable() throws {
        let credited = Set(Credit.all.compactMap(\.licence?.file))
        let bundle = Bundle(for: CatalogueStore.self)
        let shipped = Set((bundle.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? [])
            .map { $0.deletingPathExtension().lastPathComponent })
        #expect(shipped == credited)
        for credit in Credit.all {
            if let licence = credit.licence {
                #expect(licence.text?.isEmpty == false, "\(licence.file).txt")
            }
        }
    }

    @Test func theCatalogueAndTheFontAreCredited() {
        let ids = Credit.all.map(\.id)
        #expect(ids.contains("national-library"))
        #expect(ids.contains("ester"))
        #expect(ids.contains("open-library"))
        #expect(ids.contains("newsreader"))
    }

    @Test func licenceLinesAreJoinedIntoParagraphs() {
        let text = """
            Copyright 2020 The Newsreader Project Authors (http://github.com/productiontype/Newsreader)

            -----------------------------------------------------------
            SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
            -----------------------------------------------------------

            PREAMBLE
            The goals of the Open Font License (OFL) are to stimulate worldwide
            development of collaborative font projects.

            1. Copyright and Related Rights. A Work made available under CC0 may be
            protected by copyright and related or neighboring rights. These include:

              i. the right to reproduce, adapt, distribute,
                 perform and display a Work;
             ii. moral rights retained by the original author(s);

                CREATIVE COMMONS CORPORATION IS NOT A LAW FIRM AND DOES NOT PROVIDE
                LEGAL SERVICES. DISTRIBUTION OF THIS DOCUMENT DOES NOT CREATE AN
                HEREUNDER.
            """
        #expect(Credit.paragraphs(of: text) == [
            "Copyright 2020 The Newsreader Project Authors (http://github.com/productiontype/Newsreader)",
            "SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007",
            "PREAMBLE",
            "The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects.",
            "1. Copyright and Related Rights. A Work made available under CC0 may be protected by copyright and related or neighboring rights. These include:",
            "i. the right to reproduce, adapt, distribute, perform and display a Work;",
            "ii. moral rights retained by the original author(s);",
            "CREATIVE COMMONS CORPORATION IS NOT A LAW FIRM AND DOES NOT PROVIDE LEGAL SERVICES. DISTRIBUTION OF THIS DOCUMENT DOES NOT CREATE AN HEREUNDER.",
        ])
    }
}
