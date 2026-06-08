import XCTest
@testable import Edgar

final class FilingServiceTests: XCTestCase {
    let client = EdgarClient()

    func testGetFilings13F() async throws {
        let filings = try await client.getFilings(cik: 1067983, form: "13F-HR")
        XCTAssertFalse(filings.isEmpty, "Berkshire should have 13F-HR filings")
        XCTAssertTrue(filings.allSatisfy { $0.form.hasPrefix("13F-HR") })
    }

    func testFilingsAreSortedNewestFirst() async throws {
        let filings = try await client.getFilings(cik: 1067983, form: "13F-HR")
        guard filings.count >= 2 else { return }
        // Filing dates should be in descending order
        XCTAssertTrue(filings[0].filingDate >= filings[1].filingDate)
    }

    func testGetLatest13F() async throws {
        let filing = try await client.getLatest13F(cik: 1067983)
        XCTAssertTrue(filing.form.hasPrefix("13F-HR"))
        XCTAssertFalse(filing.accessionNumber.isEmpty)
        XCTAssertFalse(filing.filingDate.isEmpty)
        XCTAssertFalse(filing.reportDate.isEmpty)
        XCTAssertFalse(filing.primaryDocument.isEmpty)
    }

    func testFilingURLConstruction() async throws {
        let filing = try await client.getLatest13F(cik: 1067983)
        let dirURL = try filing.directoryURL(cik: 1067983)
        XCTAssertTrue(dirURL.absoluteString.contains("sec.gov"))
        XCTAssertTrue(dirURL.absoluteString.contains("1067983"))
        XCTAssertFalse(filing.accessionNumberClean.contains("-"))
    }

    func testFindInformationTable() async throws {
        let filing = try await client.getLatest13F(cik: 1067983)
        let url = try await client.findInformationTableURL(cik: 1067983, filing: filing)
        XCTAssertTrue(url.absoluteString.contains("sec.gov"))
        XCTAssertTrue(url.absoluteString.lowercased().hasSuffix(".xml"))
    }

    func testGetHoldings() async throws {
        let filing = try await client.getLatest13F(cik: 1067983)
        let holdings = try await client.getHoldings(cik: 1067983, filing: filing)
        XCTAssertFalse(holdings.isEmpty)
        // Berkshire typically holds 30-50 positions
        XCTAssertTrue(holdings.count > 10, "Berkshire should have >10 holdings, got \(holdings.count)")
    }

    func testGetHoldingsDataQuality() async throws {
        let filing = try await client.getLatest13F(cik: 1067983)
        let holdings = try await client.getHoldings(cik: 1067983, filing: filing)

        for holding in holdings {
            XCTAssertFalse(holding.nameOfIssuer.isEmpty, "Issuer name should not be empty")
            XCTAssertFalse(holding.cusip.isEmpty, "CUSIP should not be empty")
            XCTAssertEqual(holding.cusip.count, 9, "CUSIP should be 9 characters: \(holding.cusip)")
            XCTAssertTrue(holding.value > 0, "Value should be positive for \(holding.nameOfIssuer)")
            XCTAssertTrue(holding.shares > 0, "Shares should be positive for \(holding.nameOfIssuer)")
        }
    }

    func testBridgewaterFilings() async throws {
        // Bridgewater Associates — CIK 1350694
        let filings = try await client.getFilings(cik: 1350694, form: "13F-HR")
        XCTAssertFalse(filings.isEmpty, "Bridgewater should have 13F filings")
    }

    func testBridgewaterHoldings() async throws {
        let filing = try await client.getLatest13F(cik: 1350694)
        let holdings = try await client.getHoldings(cik: 1350694, filing: filing)
        XCTAssertFalse(holdings.isEmpty, "Bridgewater should have holdings")
        // Bridgewater typically has hundreds of positions
        XCTAssertTrue(holdings.count > 50, "Bridgewater should have >50 holdings, got \(holdings.count)")
    }

    func testSituationalAwarenessHoldings() async throws {
        // Situational Awareness Fund LP — CIK 2045724
        // Regression: primaryDocument contains subdirectory path (xslForm13F_X02/primary_doc.xml)
        // which didn't match flat filenames in the filing index, causing the parser to
        // fetch the cover page instead of the info table XML.
        let filing = try await client.getLatest13F(cik: 2045724)
        let url = try await client.findInformationTableURL(cik: 2045724, filing: filing)
        XCTAssertFalse(url.lastPathComponent == "primary_doc.xml",
                       "Should find info table XML, not cover page. Got: \(url.lastPathComponent)")

        let holdings = try await client.getHoldings(cik: 2045724, filing: filing)
        XCTAssertFalse(holdings.isEmpty, "SA Fund should have holdings")
        XCTAssertTrue(holdings.count > 5, "SA Fund should have >5 holdings, got \(holdings.count)")
    }
}
