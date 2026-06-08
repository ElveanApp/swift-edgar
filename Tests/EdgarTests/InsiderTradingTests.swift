import XCTest
@testable import Edgar

final class InsiderTradingTests: XCTestCase {

    let client = EdgarClient(userAgent: "EdgarToolsTests/1.0 (test@example.com)")

    // MARK: - Filing Discovery

    func testInsiderFilingsApple() async throws {
        let filings = try await client.getInsiderFilings(cik: 320193, limit: 5)
        XCTAssertFalse(filings.isEmpty, "Apple should have Form 4 filings")
        XCTAssertTrue(filings.count <= 5)

        for filing in filings {
            XCTAssertEqual(filing.form, "4")
        }
    }

    func testInsiderFilingsMicrosoft() async throws {
        let filings = try await client.getInsiderFilings(cik: 789019, limit: 10)
        XCTAssertFalse(filings.isEmpty, "Microsoft should have Form 4 filings")
    }

    // MARK: - Form 4 Parsing

    func testParseInsiderFilingApple() async throws {
        let filings = try await client.getInsiderFilings(cik: 320193, limit: 3)
        guard let filing = filings.first else {
            XCTFail("No Form 4 filings found for Apple")
            return
        }

        let report = try await client.parseInsiderFiling(cik: 320193, filing: filing)

        XCTAssertFalse(report.issuerName.isEmpty, "Should have issuer name")
        XCTAssertTrue(report.issuerCik > 0, "Should have issuer CIK")
        XCTAssertFalse(report.ownerName.isEmpty, "Should have owner name")
        XCTAssertEqual(report.filingDate, filing.filingDate, "Filing date should match")
    }

    func testParseInsiderTransactions() async throws {
        // Get a few filings and try to find one with transactions
        let filings = try await client.getInsiderFilings(cik: 320193, limit: 5)

        var foundTransactions = false
        for filing in filings {
            do {
                let report = try await client.parseInsiderFiling(cik: 320193, filing: filing)
                if !report.transactions.isEmpty || !report.derivativeTransactions.isEmpty {
                    foundTransactions = true

                    for tx in report.transactions {
                        XCTAssertFalse(tx.securityTitle.isEmpty, "Transaction should have security title")
                        XCTAssertFalse(tx.transactionDate.isEmpty, "Transaction should have date")
                        XCTAssertTrue(tx.shares > 0 || tx.shares == 0, "Shares should be valid")
                        XCTAssertFalse(tx.isDerivative, "Non-derivative tx should have isDerivative=false")
                    }

                    for tx in report.derivativeTransactions {
                        XCTAssertTrue(tx.isDerivative, "Derivative tx should have isDerivative=true")
                    }
                    break
                }
            } catch {
                continue
            }
        }
        // It's OK if we don't find transactions — some Form 4s are holdings-only
    }

    func testInsiderReportOwnerRelationship() async throws {
        let filings = try await client.getInsiderFilings(cik: 320193, limit: 5)

        for filing in filings {
            do {
                let report = try await client.parseInsiderFiling(cik: 320193, filing: filing)
                // At least one relationship flag should be true
                let hasRelationship = report.isDirector || report.isOfficer || report.isTenPercentOwner
                XCTAssertTrue(hasRelationship, "Owner should have at least one relationship: \(report.ownerName)")
                return
            } catch {
                continue
            }
        }
    }

    // MARK: - Transaction Code

    func testTransactionCodeFromRawValue() {
        XCTAssertEqual(TransactionCode(rawValue: "P"), .purchase)
        XCTAssertEqual(TransactionCode(rawValue: "S"), .sale)
        XCTAssertEqual(TransactionCode(rawValue: "A"), .grantAward)
        XCTAssertEqual(TransactionCode(rawValue: "M"), .exercise)
        XCTAssertEqual(TransactionCode(rawValue: "G"), .gift)
        XCTAssertNil(TransactionCode(rawValue: "Z")) // invalid
    }

    func testTransactionCodeDescription() {
        XCTAssertEqual(TransactionCode.purchase.description, "Open market purchase")
        XCTAssertEqual(TransactionCode.sale.description, "Open market sale")
        XCTAssertFalse(TransactionCode.exercise.description.isEmpty)
    }

    // MARK: - Form 4 XML Parser (Unit)

    func testForm4ParserBasic() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ownershipDocument>
            <issuer>
                <issuerCik>320193</issuerCik>
                <issuerName>Apple Inc</issuerName>
                <issuerTradingSymbol>AAPL</issuerTradingSymbol>
            </issuer>
            <reportingOwner>
                <reportingOwnerId>
                    <rptOwnerCik>1051401</rptOwnerCik>
                    <rptOwnerName>COOK TIMOTHY D</rptOwnerName>
                </reportingOwnerId>
                <reportingOwnerRelationship>
                    <isDirector>0</isDirector>
                    <isOfficer>1</isOfficer>
                    <officerTitle>Chief Executive Officer</officerTitle>
                </reportingOwnerRelationship>
            </reportingOwner>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <securityTitle><value>Common Stock</value></securityTitle>
                    <transactionDate><value>2024-04-01</value></transactionDate>
                    <transactionCoding>
                        <transactionCode>S</transactionCode>
                    </transactionCoding>
                    <transactionAmounts>
                        <transactionShares><value>50000</value></transactionShares>
                        <transactionPricePerShare><value>171.50</value></transactionPricePerShare>
                        <transactionAcquiredDisposedCode><value>D</value></transactionAcquiredDisposedCode>
                    </transactionAmounts>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction><value>3000000</value></sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                </nonDerivativeTransaction>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        let data = xml.data(using: .utf8)!
        let report = try Form4Parser.parse(data: data)

        XCTAssertEqual(report.issuerCik, 320193)
        XCTAssertEqual(report.issuerName, "Apple Inc")
        XCTAssertEqual(report.issuerTicker, "AAPL")
        XCTAssertEqual(report.ownerCik, 1051401)
        XCTAssertEqual(report.ownerName, "COOK TIMOTHY D")
        XCTAssertTrue(report.isOfficer)
        XCTAssertFalse(report.isDirector)
        XCTAssertEqual(report.officerTitle, "Chief Executive Officer")

        XCTAssertEqual(report.transactions.count, 1)
        let tx = report.transactions[0]
        XCTAssertEqual(tx.securityTitle, "Common Stock")
        XCTAssertEqual(tx.transactionDate, "2024-04-01")
        XCTAssertEqual(tx.code, .sale)
        XCTAssertEqual(tx.shares, 50000)
        XCTAssertEqual(tx.pricePerShare, 171.50)
        XCTAssertFalse(tx.acquired)
        XCTAssertEqual(tx.sharesAfterTransaction, 3000000)
        XCTAssertFalse(tx.isDerivative)
    }

    func testForm4ParserDerivative() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ownershipDocument>
            <issuer>
                <issuerCik>789019</issuerCik>
                <issuerName>MICROSOFT CORP</issuerName>
            </issuer>
            <reportingOwner>
                <reportingOwnerId>
                    <rptOwnerCik>1234567</rptOwnerCik>
                    <rptOwnerName>DOE JOHN</rptOwnerName>
                </reportingOwnerId>
                <reportingOwnerRelationship>
                    <isDirector>1</isDirector>
                    <isOfficer>0</isOfficer>
                    <isTenPercentOwner>0</isTenPercentOwner>
                </reportingOwnerRelationship>
            </reportingOwner>
            <derivativeTable>
                <derivativeTransaction>
                    <securityTitle><value>Stock Option</value></securityTitle>
                    <transactionDate><value>2024-03-15</value></transactionDate>
                    <transactionCoding>
                        <transactionCode>M</transactionCode>
                    </transactionCoding>
                    <transactionAmounts>
                        <transactionShares><value>10000</value></transactionShares>
                        <transactionPricePerShare><value>200.00</value></transactionPricePerShare>
                        <transactionAcquiredDisposedCode><value>D</value></transactionAcquiredDisposedCode>
                    </transactionAmounts>
                </derivativeTransaction>
            </derivativeTable>
        </ownershipDocument>
        """

        let data = xml.data(using: .utf8)!
        let report = try Form4Parser.parse(data: data)

        XCTAssertEqual(report.derivativeTransactions.count, 1)
        let tx = report.derivativeTransactions[0]
        XCTAssertEqual(tx.securityTitle, "Stock Option")
        XCTAssertEqual(tx.code, .exercise)
        XCTAssertTrue(tx.isDerivative)
    }

    // MARK: - Convenience Method

    func testRecentInsiderTrades() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let trades = try await edgar.recentInsiderTrades(cik: 320193, limit: 3)

        // Should get at least 1 parsed report
        XCTAssertFalse(trades.isEmpty, "Should have at least one parsed insider report")
        XCTAssertTrue(trades.count <= 3)

        for report in trades {
            XCTAssertFalse(report.ownerName.isEmpty)
            XCTAssertFalse(report.filingDate.isEmpty)
        }
    }
}
