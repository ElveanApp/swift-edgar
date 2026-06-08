import XCTest
@testable import Edgar

final class EightKTests: XCTestCase {

    let client = EdgarClient(userAgent: "EdgarToolsTests/1.0 (test@example.com)")

    // MARK: - 8-K Filing Discovery

    func testEightKFilingsApple() async throws {
        let filings = try await client.getEightKFilings(cik: 320193, limit: 5)
        XCTAssertFalse(filings.isEmpty, "Apple should have 8-K filings")
        XCTAssertTrue(filings.count <= 5)

        for eightK in filings {
            XCTAssertTrue(
                eightK.filing.form == "8-K" || eightK.filing.form == "8-K/A",
                "Form should be 8-K or 8-K/A, got \(eightK.filing.form)"
            )
        }
    }

    func testEightKFilingsHaveItems() async throws {
        // Large company should have 8-Ks with items
        let filings = try await client.getEightKFilings(cik: 320193, limit: 10)

        var foundItems = false
        for eightK in filings {
            if !eightK.items.isEmpty {
                foundItems = true
                for item in eightK.items {
                    XCTAssertFalse(item.code.isEmpty, "Item should have a code")
                    XCTAssertFalse(item.description.isEmpty, "Item should have a description")
                }
                break
            }
        }
        XCTAssertTrue(foundItems, "Should find at least one 8-K with items")
    }

    func testEightKFilingsMicrosoft() async throws {
        let filings = try await client.getEightKFilings(cik: 789019, limit: 5)
        XCTAssertFalse(filings.isEmpty, "Microsoft should have 8-K filings")
    }

    // MARK: - EightKItem Enum

    func testEightKItemFromCode() {
        XCTAssertEqual(EightKItem.from(code: "1.01").code, "1.01")
        XCTAssertEqual(EightKItem.from(code: "2.02").code, "2.02")
        XCTAssertEqual(EightKItem.from(code: "5.02").code, "5.02")
        XCTAssertEqual(EightKItem.from(code: "9.01").code, "9.01")

        // Unknown code
        let unknown = EightKItem.from(code: "99.99")
        XCTAssertEqual(unknown.code, "99.99")
        XCTAssertTrue(unknown.description.contains("Unknown"))
    }

    func testEightKItemDescriptions() {
        XCTAssertEqual(
            EightKItem.materialAgreement.description,
            "Entry into a Material Definitive Agreement"
        )
        XCTAssertEqual(
            EightKItem.resultsOfOperations.description,
            "Results of Operations and Financial Condition"
        )
        XCTAssertEqual(
            EightKItem.departureOfDirectorsOrOfficers.description,
            "Departure/Election of Directors or Principal Officers"
        )
        XCTAssertEqual(
            EightKItem.financialStatementsAndExhibits.description,
            "Financial Statements and Exhibits"
        )
    }

    func testAllEightKItemCodes() {
        // Test round-trip for all known codes
        let codes = [
            "1.01", "1.02", "1.03", "1.04",
            "2.01", "2.02", "2.03", "2.04", "2.05", "2.06",
            "3.01", "3.02", "3.03",
            "4.01", "4.02",
            "5.01", "5.02", "5.03", "5.04", "5.05", "5.06", "5.07", "5.08",
            "6.01", "7.01", "8.01", "9.01"
        ]

        for code in codes {
            let item = EightKItem.from(code: code)
            XCTAssertEqual(item.code, code, "Round-trip failed for code \(code)")
            XCTAssertFalse(item.description.contains("Unknown"), "Code \(code) should not be unknown")
        }
    }

    func testEightKItemWhitespaceTrimming() {
        let item = EightKItem.from(code: " 2.02 ")
        XCTAssertEqual(item.code, "2.02")
    }

    // MARK: - Facade

    func testFacadeEightKFilings() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let filings = try await edgar.eightKFilings(cik: 320193, limit: 3)
        XCTAssertFalse(filings.isEmpty)
        XCTAssertTrue(filings.count <= 3)
    }
}
