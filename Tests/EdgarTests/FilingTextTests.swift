import XCTest
@testable import Edgar

final class FilingTextTests: XCTestCase {

    let client = EdgarClient(userAgent: "EdgarToolsTests/1.0 (test@example.com)")

    // MARK: - HTML Stripper (Unit)

    func testStripBasicTags() {
        let html = "<p>Hello <b>world</b></p>"
        let text = HTMLStripper.stripTags(html)
        XCTAssertTrue(text.contains("Hello"))
        XCTAssertTrue(text.contains("world"))
        XCTAssertFalse(text.contains("<"))
    }

    func testStripStyleAndScript() {
        let html = """
        <html>
        <head><style>.foo { color: red; }</style></head>
        <body>
        <script>alert('xss')</script>
        <p>Content here</p>
        </body>
        </html>
        """
        let text = HTMLStripper.stripTags(html)
        XCTAssertTrue(text.contains("Content here"))
        XCTAssertFalse(text.contains("color: red"))
        XCTAssertFalse(text.contains("alert"))
    }

    func testDecodeHTMLEntities() {
        let html = "AT&amp;T &lt;Inc&gt; &quot;Hello&quot; &apos;World&apos;"
        let text = HTMLStripper.stripTags(html)
        XCTAssertTrue(text.contains("AT&T"))
        XCTAssertTrue(text.contains("<Inc>"))
        XCTAssertTrue(text.contains("\"Hello\""))
    }

    func testBlockTagsCreateNewlines() {
        let html = "<div>Line 1</div><div>Line 2</div><br><p>Line 3</p>"
        let text = HTMLStripper.stripTags(html)
        XCTAssertTrue(text.contains("Line 1"))
        XCTAssertTrue(text.contains("Line 2"))
        XCTAssertTrue(text.contains("Line 3"))
        // Lines should be on separate lines
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertTrue(lines.count >= 3, "Should have at least 3 non-empty lines, got \(lines.count)")
    }

    func testStripNbsp() {
        let html = "Hello&nbsp;world&#160;!"
        let text = HTMLStripper.stripTags(html)
        XCTAssertTrue(text.contains("Hello world !") || text.contains("Hello world!"))
    }

    func testCollapseWhitespace() {
        let html = "<p>Line 1</p>\n\n\n\n\n<p>Line 2</p>"
        let text = HTMLStripper.stripTags(html)
        // Should not have more than 2 consecutive newlines
        XCTAssertFalse(text.contains("\n\n\n"))
    }

    func testEmptyInput() {
        XCTAssertEqual(HTMLStripper.stripTags(""), "")
    }

    func testPlainTextPassthrough() {
        let plain = "No HTML here, just plain text."
        let text = HTMLStripper.stripTags(plain)
        XCTAssertEqual(text, plain)
    }

    // MARK: - Filing HTML Download (Integration)

    func testGetFilingHTML() async throws {
        // Get Apple's latest 10-K or 10-Q filing
        let filings = try await client.getFilings(cik: 320193)
        let tenK = filings.first { $0.form == "10-K" || $0.form == "10-Q" }
        guard let filing = tenK else {
            // Just try the first filing if no 10-K/Q found
            guard let f = filings.first else { return }
            let html = try await client.getFilingHTML(cik: 320193, filing: f)
            XCTAssertFalse(html.isEmpty)
            return
        }

        let html = try await client.getFilingHTML(cik: 320193, filing: filing)
        XCTAssertFalse(html.isEmpty, "Filing HTML should not be empty")
        // HTML filings typically have these markers
        XCTAssertTrue(
            html.contains("<") || html.lowercased().contains("html") || html.count > 1000,
            "Should look like HTML content"
        )
    }

    func testGetFilingText() async throws {
        let filings = try await client.getFilings(cik: 320193)
        guard let filing = filings.first else { return }

        let text = try await client.getFilingText(cik: 320193, filing: filing)
        XCTAssertFalse(text.isEmpty, "Filing text should not be empty")
        XCTAssertFalse(text.contains("<style"), "Should not contain style tags")
        XCTAssertFalse(text.contains("<script"), "Should not contain script tags")
    }

    // MARK: - Full Filing History (Pagination)

    func testGetAllFilingsWithPagination() async throws {
        // Apple has many filings — test pagination
        let allFilings = try await client.getAllFilings(cik: 320193)
        let recentFilings = try await client.getFilings(cik: 320193)

        // Full history should have at least as many as recent
        XCTAssertTrue(
            allFilings.count >= recentFilings.count,
            "All filings (\(allFilings.count)) should >= recent (\(recentFilings.count))"
        )
    }

    func testGetAllFilingsFiltered() async throws {
        let tenKFilings = try await client.getAllFilings(cik: 320193, form: "10-K")

        XCTAssertFalse(tenKFilings.isEmpty, "Apple should have 10-K filings")
        for filing in tenKFilings {
            XCTAssertTrue(
                filing.form == "10-K" || filing.form == "10-K/A",
                "Expected 10-K, got \(filing.form)"
            )
        }

        // Apple has been public since 1980 — should have many 10-Ks
        XCTAssertTrue(tenKFilings.count >= 10, "Apple should have 10+ 10-K filings, got \(tenKFilings.count)")
    }

    // MARK: - Facade

    func testFacadeFilingText() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let filings = try await edgar.allFilings(cik: 320193, form: "10-K")
        guard let filing = filings.first else { return }

        let text = try await edgar.filingText(cik: 320193, filing: filing)
        XCTAssertFalse(text.isEmpty)
    }

    func testFacadeAllFilings() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let filings = try await edgar.allFilings(cik: 320193)
        XCTAssertTrue(filings.count > 40, "Full history should have many filings")
    }
}
