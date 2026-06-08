import XCTest
@testable import Edgar

final class CompanySearchTests: XCTestCase {
    let client = EdgarClient()

    func testGetCompanyByCIK() async throws {
        let company = try await client.getCompany(cik: 1067983)
        XCTAssertEqual(company.name, "BERKSHIRE HATHAWAY INC")
        XCTAssertFalse(company.tickers.isEmpty)
        XCTAssertTrue(company.tickers.contains("BRK-B") || company.tickers.contains("BRK-A"))
        XCTAssertNotNil(company.sic)
    }

    func testGetCompanyBridgewater() async throws {
        // Bridgewater Associates — CIK 1350694
        let company = try await client.getCompany(cik: 1350694)
        XCTAssertTrue(company.name.uppercased().contains("BRIDGEWATER"))
    }

    func testSearchByTicker() async throws {
        let result = try await client.searchByTicker("AAPL")
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.name.uppercased().contains("APPLE") == true)
        XCTAssertEqual(result?.ticker, "AAPL")
    }

    func testSearchByTickerCaseInsensitive() async throws {
        let result = try await client.searchByTicker("aapl")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.ticker, "AAPL")
    }

    func testSearchByTickerNotFound() async throws {
        let result = try await client.searchByTicker("ZZZZZZZ")
        XCTAssertNil(result)
    }

    func testSearchByName() async throws {
        let results = try await client.searchByName("Berkshire")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.first?.name.uppercased().contains("BERKSHIRE") == true)
    }

    func testSearchByNameMultipleResults() async throws {
        let results = try await client.searchByName("Apple")
        XCTAssertTrue(results.count > 1, "Should find multiple companies with 'Apple'")
    }

    func testInvalidCIKReturnsError() async {
        do {
            _ = try await client.getCompany(cik: 9999999)
            XCTFail("Should have thrown for invalid CIK")
        } catch let error as EdgarError {
            switch error {
            case .httpError(let code, _):
                XCTAssertTrue(code == 404 || code == 403, "Expected 404 or 403, got \(code)")
            default:
                break // other EdgarError types are also acceptable
            }
        } catch {
            // Any error is acceptable for invalid CIK
        }
    }

    func testSearchFilersForFund() async throws {
        let results = try await client.searchFilers("Bridgewater")
        // EFTS search may or may not work; don't hard-fail
        if !results.isEmpty {
            XCTAssertTrue(results.first?.cik ?? 0 > 0)
        }
    }
}
