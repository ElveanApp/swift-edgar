import XCTest
@testable import Edgar

final class CUSIPMapperTests: XCTestCase {
    let mapper = CUSIPMapper()

    func testResolveAppleCUSIP() async {
        let result = await mapper.resolve(["037833100"])
        XCTAssertEqual(result["037833100"], "AAPL")
    }

    func testResolveMicrosoftCUSIP() async {
        let result = await mapper.resolve(["594918104"])
        XCTAssertEqual(result["594918104"], "MSFT")
    }

    func testResolveBatchCUSIPs() async {
        let cusips = ["037833100", "594918104", "88160R101"] // AAPL, MSFT, TSLA
        let result = await mapper.resolve(cusips)
        XCTAssertEqual(result["037833100"], "AAPL")
        XCTAssertEqual(result["594918104"], "MSFT")
        // TSLA CUSIP may resolve
        if let tsla = result["88160R101"] {
            XCTAssertEqual(tsla, "TSLA")
        }
    }

    func testCachingReturnsSameResults() async {
        // First call — hits OpenFIGI
        let result1 = await mapper.resolve(["037833100"])
        XCTAssertEqual(result1["037833100"], "AAPL")

        // Second call — should use cache
        let result2 = await mapper.resolve(["037833100"])
        XCTAssertEqual(result2["037833100"], "AAPL")
    }

    func testInvalidCUSIPReturnsEmpty() async {
        let result = await mapper.resolve(["XXXXXXXXX"])
        XCTAssertNil(result["XXXXXXXXX"])
    }

    func testResolveHoldings() async {
        let holdings = [
            Holding(
                nameOfIssuer: "APPLE INC",
                titleOfClass: "COM",
                cusip: "037833100",
                value: 50000,
                shares: 1000000,
                shareType: .shares,
                investmentDiscretion: .sole,
                votingSole: 1000000,
                votingShared: 0,
                votingNone: 0
            ),
            Holding(
                nameOfIssuer: "MICROSOFT CORP",
                titleOfClass: "COM",
                cusip: "594918104",
                value: 30000,
                shares: 500000,
                shareType: .shares,
                investmentDiscretion: .sole,
                votingSole: 500000,
                votingShared: 0,
                votingNone: 0
            ),
        ]

        let resolved = await mapper.resolveHoldings(holdings)
        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].ticker, "AAPL")
        XCTAssertEqual(resolved[1].ticker, "MSFT")
    }

    func testResolveDeduplicates() async {
        // Same CUSIP multiple times should only make one API call
        let cusips = ["037833100", "037833100", "037833100"]
        let result = await mapper.resolve(cusips)
        XCTAssertEqual(result["037833100"], "AAPL")
    }

    func testEmptyInputReturnsEmpty() async {
        let result = await mapper.resolve([])
        XCTAssertTrue(result.isEmpty)
    }
}
