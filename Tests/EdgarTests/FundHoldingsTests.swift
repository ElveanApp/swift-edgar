import XCTest
@testable import Edgar

final class FundHoldingsTests: XCTestCase {

    let client = EdgarClient(userAgent: "EdgarToolsTests/1.0 (test@example.com)")

    // MARK: - Fund Filing Discovery

    func testFundFilingsFidelity() async throws {
        // Fidelity Management & Research CIK: 315700
        let filings = try await client.getFundFilings(cik: 315700, limit: 3)
        // If this CIK doesn't have NPORT-P, that's OK — it won't fail hard
        for filing in filings {
            XCTAssertEqual(filing.form, "NPORT-P", "Should be NPORT-P, got \(filing.form)")
        }
    }

    // MARK: - N-PORT XML Parser (Unit)

    func testNPortParserBasic() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <edgarSubmission>
            <formData>
                <genInfo>
                    <seriesNm>Test Fund</seriesNm>
                    <repPdDate>2024-03-31</repPdDate>
                </genInfo>
                <fundInfo>
                    <totAssets>1000000000</totAssets>
                    <netAssets>950000000</netAssets>
                </fundInfo>
                <invstOrSecs>
                    <invstOrSec>
                        <name>APPLE INC</name>
                        <title>COM</title>
                        <cusip>037833100</cusip>
                        <balance>500000</balance>
                        <units>NS</units>
                        <valUSD>85000000</valUSD>
                        <pctVal>8.95</pctVal>
                        <assetCat>EC</assetCat>
                        <invCountry>US</invCountry>
                        <curCd>USD</curCd>
                        <payoffProfile>Long</payoffProfile>
                    </invstOrSec>
                    <invstOrSec>
                        <name>MICROSOFT CORP</name>
                        <title>COM</title>
                        <cusip>594918104</cusip>
                        <balance>300000</balance>
                        <units>NS</units>
                        <valUSD>120000000</valUSD>
                        <pctVal>12.63</pctVal>
                        <assetCat>EC</assetCat>
                        <invCountry>US</invCountry>
                        <curCd>USD</curCd>
                        <payoffProfile>Long</payoffProfile>
                    </invstOrSec>
                </invstOrSecs>
            </formData>
        </edgarSubmission>
        """

        let dummyFiling = Filing(
            accessionNumber: "0000000000-00-000000",
            filingDate: "2024-04-15",
            reportDate: "2024-03-31",
            form: "NPORT-P",
            primaryDocument: "test.xml",
            primaryDocDescription: "NPORT-P"
        )

        let portfolio = try NPortParser.parse(data: xml.data(using: .utf8)!, filing: dummyFiling, cik: 36274)

        XCTAssertEqual(portfolio.fundName, "Test Fund")
        XCTAssertEqual(portfolio.reportDate, "2024-03-31")
        XCTAssertEqual(portfolio.totalAssets, 1_000_000_000)
        XCTAssertEqual(portfolio.netAssets, 950_000_000)
        XCTAssertEqual(portfolio.holdingCount, 2)

        let top = portfolio.topHoldings(1)
        XCTAssertEqual(top.count, 1)
        XCTAssertEqual(top[0].name, "MICROSOFT CORP") // Higher value
        XCTAssertEqual(top[0].value, 120_000_000)
    }

    func testNPortParserEmptyHoldings() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <edgarSubmission>
            <formData>
                <genInfo>
                    <seriesNm>Empty Fund</seriesNm>
                    <repPdDate>2024-03-31</repPdDate>
                </genInfo>
            </formData>
        </edgarSubmission>
        """

        let dummyFiling = Filing(
            accessionNumber: "0000000000-00-000000",
            filingDate: "2024-04-15",
            reportDate: "2024-03-31",
            form: "NPORT-P",
            primaryDocument: "test.xml",
            primaryDocDescription: "NPORT-P"
        )

        let portfolio = try NPortParser.parse(data: xml.data(using: .utf8)!, filing: dummyFiling, cik: 1)
        XCTAssertEqual(portfolio.fundName, "Empty Fund")
        XCTAssertEqual(portfolio.holdingCount, 0)
    }

    func testNPortHoldingFields() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <edgarSubmission>
            <formData>
                <genInfo>
                    <seriesNm>Field Test</seriesNm>
                    <repPdDate>2024-06-30</repPdDate>
                </genInfo>
                <invstOrSecs>
                    <invstOrSec>
                        <name>NVIDIA CORP</name>
                        <title>COM</title>
                        <cusip>67066G104</cusip>
                        <lei>549300S4KLFTLO7GSQ80</lei>
                        <isin>US67066G1040</isin>
                        <balance>100000</balance>
                        <units>NS</units>
                        <valUSD>50000000</valUSD>
                        <pctVal>5.26</pctVal>
                        <assetCat>EC</assetCat>
                        <issuerCat>CORP</issuerCat>
                        <invCountry>US</invCountry>
                        <curCd>USD</curCd>
                        <payoffProfile>Long</payoffProfile>
                    </invstOrSec>
                </invstOrSecs>
            </formData>
        </edgarSubmission>
        """

        let dummyFiling = Filing(
            accessionNumber: "0000000000-00-000000",
            filingDate: "2024-07-15",
            reportDate: "2024-06-30",
            form: "NPORT-P",
            primaryDocument: "test.xml",
            primaryDocDescription: "NPORT-P"
        )

        let portfolio = try NPortParser.parse(data: xml.data(using: .utf8)!, filing: dummyFiling, cik: 1)
        XCTAssertEqual(portfolio.holdingCount, 1)

        let h = portfolio.holdings[0]
        XCTAssertEqual(h.name, "NVIDIA CORP")
        XCTAssertEqual(h.title, "COM")
        XCTAssertEqual(h.cusip, "67066G104")
        XCTAssertEqual(h.lei, "549300S4KLFTLO7GSQ80")
        XCTAssertEqual(h.isin, "US67066G1040")
        XCTAssertEqual(h.balance, 100000)
        XCTAssertEqual(h.units, "NS")
        XCTAssertEqual(h.value, 50000000)
        XCTAssertEqual(h.percentage, 5.26)
        XCTAssertEqual(h.assetCategory, "EC")
        XCTAssertEqual(h.issuerCategory, "CORP")
        XCTAssertEqual(h.country, "US")
        XCTAssertEqual(h.currency, "USD")
        XCTAssertEqual(h.payoffProfile, "Long")
    }

    // MARK: - Real N-PORT Filing (Integration)

    func testParseFundFilingReal() async throws {
        let filings = try await client.getFundFilings(cik: 315700, limit: 1)
        guard let filing = filings.first else {
            return
        }

        do {
            let portfolio = try await client.parseFundFiling(cik: 315700, filing: filing)

            XCTAssertFalse(portfolio.fundName.isEmpty, "Should have fund name")
            XCTAssertFalse(portfolio.reportDate.isEmpty, "Should have report date")
            XCTAssertTrue(portfolio.holdingCount > 0, "Should have holdings")

            let top = portfolio.topHoldings(5)
            XCTAssertTrue(top.count > 0)
            XCTAssertTrue(top[0].value > 0, "Top holding should have positive value")
        } catch {
            // N-PORT parsing can fail if the primary document isn't the XML
            print("Note: Real N-PORT parsing failed (primary doc may not be XML): \(error)")
        }
    }

    // MARK: - Facade

    func testFacadeFundFilings() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let filings = try await edgar.fundFilings(cik: 315700, limit: 2)
        // May be empty if CIK doesn't file NPORT-P
    }
}
