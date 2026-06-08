import XCTest
@testable import Edgar

final class ThirteenFParserTests: XCTestCase {

    func testParseSingleHolding() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <informationTable xmlns="http://www.sec.gov/Archives/edgar">
          <infoTable>
            <nameOfIssuer>APPLE INC</nameOfIssuer>
            <titleOfClass>COM</titleOfClass>
            <cusip>037833100</cusip>
            <value>50000</value>
            <shrsOrPrnAmt>
              <sshPrnamt>1000000</sshPrnamt>
              <sshPrnamtType>SH</sshPrnamtType>
            </shrsOrPrnAmt>
            <investmentDiscretion>SOLE</investmentDiscretion>
            <votingAuthority>
              <Sole>1000000</Sole>
              <Shared>0</Shared>
              <None>0</None>
            </votingAuthority>
          </infoTable>
        </informationTable>
        """

        let holdings = try ThirteenFParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(holdings.count, 1)

        let apple = holdings[0]
        XCTAssertEqual(apple.nameOfIssuer, "APPLE INC")
        XCTAssertEqual(apple.titleOfClass, "COM")
        XCTAssertEqual(apple.cusip, "037833100")
        XCTAssertEqual(apple.value, 50000)
        XCTAssertEqual(apple.shares, 1000000)
        XCTAssertEqual(apple.shareType, .shares)
        XCTAssertNil(apple.putCall)
        XCTAssertEqual(apple.investmentDiscretion, .sole)
        XCTAssertEqual(apple.votingSole, 1000000)
        XCTAssertEqual(apple.votingShared, 0)
        XCTAssertEqual(apple.votingNone, 0)
        XCTAssertNil(apple.ticker)
        XCTAssertEqual(apple.marketValue, 50_000_000)
    }

    func testParseMultipleHoldings() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <informationTable>
          <infoTable>
            <nameOfIssuer>APPLE INC</nameOfIssuer>
            <titleOfClass>COM</titleOfClass>
            <cusip>037833100</cusip>
            <value>50000</value>
            <shrsOrPrnAmt>
              <sshPrnamt>1000000</sshPrnamt>
              <sshPrnamtType>SH</sshPrnamtType>
            </shrsOrPrnAmt>
            <investmentDiscretion>SOLE</investmentDiscretion>
            <votingAuthority>
              <Sole>1000000</Sole>
              <Shared>0</Shared>
              <None>0</None>
            </votingAuthority>
          </infoTable>
          <infoTable>
            <nameOfIssuer>MICROSOFT CORP</nameOfIssuer>
            <titleOfClass>COM</titleOfClass>
            <cusip>594918104</cusip>
            <value>30000</value>
            <shrsOrPrnAmt>
              <sshPrnamt>500000</sshPrnamt>
              <sshPrnamtType>SH</sshPrnamtType>
            </shrsOrPrnAmt>
            <investmentDiscretion>SOLE</investmentDiscretion>
            <votingAuthority>
              <Sole>500000</Sole>
              <Shared>0</Shared>
              <None>0</None>
            </votingAuthority>
          </infoTable>
          <infoTable>
            <nameOfIssuer>AMAZON COM INC</nameOfIssuer>
            <titleOfClass>COM</titleOfClass>
            <cusip>023135106</cusip>
            <value>20000</value>
            <shrsOrPrnAmt>
              <sshPrnamt>200000</sshPrnamt>
              <sshPrnamtType>SH</sshPrnamtType>
            </shrsOrPrnAmt>
            <investmentDiscretion>DFND</investmentDiscretion>
            <votingAuthority>
              <Sole>100000</Sole>
              <Shared>50000</Shared>
              <None>50000</None>
            </votingAuthority>
          </infoTable>
        </informationTable>
        """

        let holdings = try ThirteenFParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(holdings.count, 3)
        XCTAssertEqual(holdings[0].nameOfIssuer, "APPLE INC")
        XCTAssertEqual(holdings[1].nameOfIssuer, "MICROSOFT CORP")
        XCTAssertEqual(holdings[2].nameOfIssuer, "AMAZON COM INC")
        XCTAssertEqual(holdings[2].investmentDiscretion, .defined)
        XCTAssertEqual(holdings[2].votingShared, 50000)
    }

    func testParsePutCallOption() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <informationTable>
          <infoTable>
            <nameOfIssuer>TESLA INC</nameOfIssuer>
            <titleOfClass>COM</titleOfClass>
            <cusip>88160R101</cusip>
            <value>10000</value>
            <shrsOrPrnAmt>
              <sshPrnamt>50000</sshPrnamt>
              <sshPrnamtType>SH</sshPrnamtType>
            </shrsOrPrnAmt>
            <putCall>PUT</putCall>
            <investmentDiscretion>DFND</investmentDiscretion>
            <votingAuthority>
              <Sole>0</Sole>
              <Shared>0</Shared>
              <None>50000</None>
            </votingAuthority>
          </infoTable>
        </informationTable>
        """

        let holdings = try ThirteenFParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].putCall, .put)
        XCTAssertEqual(holdings[0].investmentDiscretion, .defined)
        XCTAssertEqual(holdings[0].votingNone, 50000)
    }

    func testParseCallOption() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <informationTable>
          <infoTable>
            <nameOfIssuer>NVIDIA CORP</nameOfIssuer>
            <titleOfClass>COM</titleOfClass>
            <cusip>67066G104</cusip>
            <value>5000</value>
            <shrsOrPrnAmt>
              <sshPrnamt>10000</sshPrnamt>
              <sshPrnamtType>SH</sshPrnamtType>
            </shrsOrPrnAmt>
            <putCall>CALL</putCall>
            <investmentDiscretion>SOLE</investmentDiscretion>
            <votingAuthority>
              <Sole>0</Sole>
              <Shared>0</Shared>
              <None>10000</None>
            </votingAuthority>
          </infoTable>
        </informationTable>
        """

        let holdings = try ThirteenFParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(holdings[0].putCall, .call)
    }

    func testParsePrincipalShares() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <informationTable>
          <infoTable>
            <nameOfIssuer>US TREASURY BOND</nameOfIssuer>
            <titleOfClass>NOTE</titleOfClass>
            <cusip>912810SZ9</cusip>
            <value>100000</value>
            <shrsOrPrnAmt>
              <sshPrnamt>100000000</sshPrnamt>
              <sshPrnamtType>PRN</sshPrnamtType>
            </shrsOrPrnAmt>
            <investmentDiscretion>SOLE</investmentDiscretion>
            <votingAuthority>
              <Sole>0</Sole>
              <Shared>0</Shared>
              <None>0</None>
            </votingAuthority>
          </infoTable>
        </informationTable>
        """

        let holdings = try ThirteenFParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(holdings[0].shareType, .principal)
    }

    func testParseWithNamespacePrefix() throws {
        // Some filings use namespace prefixes
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ns1:informationTable xmlns:ns1="http://www.sec.gov/Archives/edgar">
          <ns1:infoTable>
            <ns1:nameOfIssuer>ALPHABET INC</ns1:nameOfIssuer>
            <ns1:titleOfClass>CL A</ns1:titleOfClass>
            <ns1:cusip>02079K305</ns1:cusip>
            <ns1:value>25000</ns1:value>
            <ns1:shrsOrPrnAmt>
              <ns1:sshPrnamt>300000</ns1:sshPrnamt>
              <ns1:sshPrnamtType>SH</ns1:sshPrnamtType>
            </ns1:shrsOrPrnAmt>
            <ns1:investmentDiscretion>SOLE</ns1:investmentDiscretion>
            <ns1:votingAuthority>
              <ns1:Sole>300000</ns1:Sole>
              <ns1:Shared>0</ns1:Shared>
              <ns1:None>0</ns1:None>
            </ns1:votingAuthority>
          </ns1:infoTable>
        </ns1:informationTable>
        """

        let holdings = try ThirteenFParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings[0].nameOfIssuer, "ALPHABET INC")
        XCTAssertEqual(holdings[0].titleOfClass, "CL A")
        XCTAssertEqual(holdings[0].shares, 300000)
    }

    func testParseEmptyXMLThrows() {
        let xml = "<?xml version=\"1.0\"?><root></root>"
        XCTAssertThrowsError(try ThirteenFParser.parse(data: Data(xml.utf8))) { error in
            guard let edgarError = error as? EdgarError else {
                XCTFail("Expected EdgarError"); return
            }
            if case .xmlParsingError = edgarError {
                // Expected
            } else {
                XCTFail("Expected xmlParsingError, got \(edgarError)")
            }
        }
    }

    func testParseInvalidXMLThrows() {
        let xml = "this is not xml at all"
        XCTAssertThrowsError(try ThirteenFParser.parse(data: Data(xml.utf8)))
    }

    // MARK: - Integration: Parse a real SEC filing

    func testParseRealBerkshireFiling() async throws {
        let client = EdgarClient()
        let filing = try await client.getLatest13F(cik: 1067983)
        let holdings = try await client.getHoldings(cik: 1067983, filing: filing)

        XCTAssertTrue(holdings.count > 10, "Berkshire should have >10 holdings")

        // Verify data quality across all holdings
        for holding in holdings {
            XCTAssertFalse(holding.nameOfIssuer.isEmpty)
            XCTAssertFalse(holding.cusip.isEmpty)
            XCTAssertTrue(holding.value > 0, "\(holding.nameOfIssuer) should have positive value")
            XCTAssertTrue(holding.shares > 0, "\(holding.nameOfIssuer) should have positive shares")
        }

        // Berkshire's Apple position is their largest holding
        let apple = holdings.first { $0.cusip == "037833100" }
        if let apple {
            XCTAssertEqual(apple.nameOfIssuer, "APPLE INC")
            // Apple position should be worth billions (value is in thousands)
            XCTAssertTrue(apple.value > 1_000_000, "Apple position should be >$1B")
        }
    }
}
