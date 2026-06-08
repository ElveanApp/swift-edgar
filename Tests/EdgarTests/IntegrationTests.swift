import XCTest
@testable import Edgar

/// End-to-end integration tests using real SEC EDGAR API calls.
/// These tests verify the full pipeline: search → filings → parse → ticker resolution.
final class IntegrationTests: XCTestCase {
    let edgar = Edgar()

    // MARK: - Full Pipeline

    func testFullPipelineBerkshire() async throws {
        // 1. Get company
        let company = try await edgar.company(cik: 1067983)
        XCTAssertEqual(company.name, "BERKSHIRE HATHAWAY INC")

        // 2. Get latest portfolio with ticker resolution
        let portfolio = try await edgar.latestPortfolio(cik: 1067983)

        // 3. Verify portfolio structure
        XCTAssertTrue(portfolio.positionCount > 10)
        XCTAssertTrue(portfolio.totalValue > 0)
        XCTAssertEqual(portfolio.company.name, "BERKSHIRE HATHAWAY INC")

        // 4. Check top holdings are sorted
        let top = portfolio.topHoldings(5)
        XCTAssertEqual(top.count, 5)
        for i in 0..<(top.count - 1) {
            XCTAssertTrue(top[i].value >= top[i + 1].value, "Top holdings should be sorted by value")
        }

        // 5. Verify ticker resolution worked for at least some holdings
        let withTickers = portfolio.holdings.filter { $0.ticker != nil }
        XCTAssertFalse(withTickers.isEmpty, "At least some holdings should have tickers resolved")

        // 6. Portfolio weights should sum to ~100%
        let totalWeight = portfolio.holdings.reduce(0.0) { $0 + portfolio.weight(of: $1) }
        XCTAssertEqual(totalWeight, 100.0, accuracy: 0.1)
    }

    func testPortfolioWithoutTickerResolution() async throws {
        let portfolio = try await edgar.latestPortfolio(cik: 1067983, resolveTickers: false)
        XCTAssertTrue(portfolio.positionCount > 10)

        // All tickers should be nil when resolution is disabled
        let withTickers = portfolio.holdings.filter { $0.ticker != nil }
        XCTAssertTrue(withTickers.isEmpty, "No holdings should have tickers when resolution is disabled")
    }

    // MARK: - Quarter Comparison

    func testCompareQuarters() async throws {
        let comparison = try await edgar.compareQuarters(cik: 1067983, resolveTickers: false)

        XCTAssertTrue(comparison.current.positionCount > 0)
        XCTAssertTrue(comparison.previous.positionCount > 0)
        XCTAssertTrue(comparison.current.filing.filingDate >= comparison.previous.filing.filingDate)

        // Verify all categories are populated (at least the structure is correct)
        let totalPositions = comparison.newPositions.count +
            comparison.closedPositions.count +
            comparison.increasedPositions.count +
            comparison.decreasedPositions.count +
            comparison.unchangedPositions.count
        XCTAssertTrue(totalPositions > 0, "Should have at least some positions across all categories")

        // Position changes should have valid data
        for change in comparison.increasedPositions {
            XCTAssertTrue(change.shareChange > 0)
            XCTAssertTrue(change.percentChange > 0)
            XCTAssertFalse(change.cusip.isEmpty)
        }

        for change in comparison.decreasedPositions {
            XCTAssertTrue(change.shareChange < 0)
            XCTAssertTrue(change.percentChange < 0)
        }
    }

    // MARK: - Company Search → Portfolio

    func testSearchAndGetPortfolio() async throws {
        let results = try await edgar.searchCompanies("Berkshire")
        XCTAssertFalse(results.isEmpty)

        let berkshire = results.first { $0.name.uppercased().contains("BERKSHIRE HATHAWAY") }
        XCTAssertNotNil(berkshire)

        if let berkshire {
            let portfolio = try await edgar.latestPortfolio(cik: berkshire.cik, resolveTickers: false)
            XCTAssertTrue(portfolio.positionCount > 10)
        }
    }

    func testTickerSearchToPortfolio() async throws {
        let result = try await edgar.company(ticker: "BRK-B")
        XCTAssertNotNil(result)

        if let result {
            let filings = try await edgar.filings(cik: result.cik)
            XCTAssertFalse(filings.isEmpty)
        }
    }

    // MARK: - Multiple Filers

    func testBridgewaterPortfolio() async throws {
        let portfolio = try await edgar.latestPortfolio(cik: 1350694, resolveTickers: false)
        XCTAssertTrue(portfolio.positionCount > 50, "Bridgewater should have >50 positions")
        XCTAssertTrue(portfolio.totalValue > 0)
    }

    func testMultipleFilers() async throws {
        let filers: [(cik: Int, name: String, minPositions: Int)] = [
            (1067983, "Berkshire Hathaway", 10),
            (1350694, "Bridgewater Associates", 50),
        ]

        for filer in filers {
            let filings = try await edgar.filings(cik: filer.cik)
            XCTAssertFalse(filings.isEmpty, "\(filer.name) should have 13F filings")

            let portfolio = try await edgar.latestPortfolio(cik: filer.cik, resolveTickers: false)
            XCTAssertTrue(
                portfolio.positionCount > filer.minPositions,
                "\(filer.name) should have >\(filer.minPositions) positions, got \(portfolio.positionCount)"
            )
        }
    }

    // MARK: - Portfolio Convenience Methods

    func testPortfolioLookups() async throws {
        let portfolio = try await edgar.latestPortfolio(cik: 1067983, resolveTickers: false)

        // Find Apple by CUSIP
        let apple = portfolio.holding(forCUSIP: "037833100")
        if let apple {
            XCTAssertEqual(apple.nameOfIssuer, "APPLE INC")
            XCTAssertTrue(portfolio.weight(of: apple) > 0)
            XCTAssertTrue(apple.marketValue > 0)
            XCTAssertEqual(apple.label, apple.cusip) // no ticker resolved
        }

        // Top holdings should have reasonable weights
        let top = portfolio.topHoldings(3)
        for holding in top {
            let weight = portfolio.weight(of: holding)
            XCTAssertTrue(weight > 0)
            XCTAssertTrue(weight <= 100)
        }
    }

    func testPortfolioWithTickerLookup() async throws {
        let portfolio = try await edgar.latestPortfolio(cik: 1067983, resolveTickers: true)

        let apple = portfolio.holding(forTicker: "AAPL")
        if let apple {
            XCTAssertEqual(apple.nameOfIssuer, "APPLE INC")
            XCTAssertEqual(apple.label, "AAPL") // ticker should be used as label
        }
    }

    // MARK: - Filings List

    func testFilingsMetadata() async throws {
        let filings = try await edgar.filings(cik: 1067983)
        XCTAssertFalse(filings.isEmpty)

        let latest = filings[0]
        // Report date should be a quarter end (03-31, 06-30, 09-30, 12-31)
        let quarterEnds = ["03-31", "06-30", "09-30", "12-31"]
        let isQuarterEnd = quarterEnds.contains { latest.reportDate.hasSuffix($0) }
        XCTAssertTrue(isQuarterEnd, "Report date \(latest.reportDate) should be a quarter end")
    }

    func testLatestFiling() async throws {
        let filing = try await edgar.latestFiling(cik: 1067983)
        XCTAssertTrue(filing.form.hasPrefix("13F-HR"))
        XCTAssertFalse(filing.accessionNumber.isEmpty)
    }
}
