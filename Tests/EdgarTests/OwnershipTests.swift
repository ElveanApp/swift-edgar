import XCTest
@testable import Edgar

final class OwnershipTests: XCTestCase {

    let client = EdgarClient(userAgent: "EdgarToolsTests/1.0 (test@example.com)")

    // MARK: - 13D/G Ownership Filings

    func testOwnershipFilingsApple() async throws {
        let filings = try await client.getOwnershipFilings(cik: 320193, limit: 5)
        // Apple may or may not have 13D/G filings (they're for 5%+ owners)
        // Just verify the call succeeds and returns valid filings
        for filing in filings {
            XCTAssertTrue(
                filing.form.hasPrefix("SC 13D") || filing.form.hasPrefix("SC 13G"),
                "Expected 13D/G form, got \(filing.form)"
            )
        }
    }

    // MARK: - Proxy Filings (DEF 14A)

    func testProxyFilingsApple() async throws {
        let filings = try await client.getProxyFilings(cik: 320193, limit: 3)
        XCTAssertFalse(filings.isEmpty, "Apple should have proxy statement filings")

        for filing in filings {
            XCTAssertTrue(
                filing.form == "DEF 14A" || filing.form == "DEFA14A",
                "Expected proxy form, got \(filing.form)"
            )
        }
    }

    func testProxyFilingsMicrosoft() async throws {
        let filings = try await client.getProxyFilings(cik: 789019, limit: 3)
        XCTAssertFalse(filings.isEmpty, "Microsoft should have proxy statement filings")
    }

    // MARK: - Registration Filings (S-1)

    func testRegistrationFilings() async throws {
        // Tesla CIK: 1318605 — had S-1 when it went public
        let filings = try await client.getRegistrationFilings(cik: 1318605, limit: 5)
        // May or may not have them in recent history
        for filing in filings {
            XCTAssertTrue(
                filing.form.hasPrefix("S-1") || filing.form.hasPrefix("S-3") || filing.form.hasPrefix("S-4"),
                "Expected registration form, got \(filing.form)"
            )
        }
    }

    // MARK: - Form D (Private Offerings)

    func testFormDFilings() async throws {
        // Use a company that might have Form D filings
        // Stripe (might not be in EDGAR) or try a well-known startup
        // Instead, just test the API call mechanism works
        let filings = try await client.getFormDFilings(cik: 320193, limit: 5)
        // Apple probably doesn't have Form D filings, but the call should succeed
        for filing in filings {
            XCTAssertEqual(filing.form, "D")
        }
    }

    // MARK: - Form D XML Parser (Unit)

    func testFormDParserBasic() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <edgarSubmission>
            <primaryIssuer>
                <entityName>Test Startup Inc</entityName>
                <cik>9999999</cik>
                <entityType>Corporation</entityType>
                <industryGroupType>Technology</industryGroupType>
                <revenueRange>No Revenues</revenueRange>
            </primaryIssuer>
            <offeringData>
                <federalExemptionsExclusions>
                    <item>06b</item>
                    <item>3C.1</item>
                </federalExemptionsExclusions>
                <dateOfFirstSale>2024-01-15</dateOfFirstSale>
                <offeringSalesAmounts>
                    <totalOfferingAmount>50000000</totalOfferingAmount>
                    <totalAmountSold>25000000</totalAmountSold>
                    <totalRemaining>25000000</totalRemaining>
                </offeringSalesAmounts>
            </offeringData>
        </edgarSubmission>
        """

        let offering = try FormDParser.parse(data: xml.data(using: .utf8)!)

        XCTAssertEqual(offering.entityName, "Test Startup Inc")
        XCTAssertEqual(offering.entityCik, 9999999)
        XCTAssertEqual(offering.entityType, "Corporation")
        XCTAssertEqual(offering.industryGroup, "Technology")
        XCTAssertEqual(offering.revenueRange, "No Revenues")
        XCTAssertEqual(offering.federalExemptions, ["06b", "3C.1"])
        XCTAssertEqual(offering.dateOfFirstSale, "2024-01-15")
        XCTAssertEqual(offering.totalOfferingAmount, 50_000_000)
        XCTAssertEqual(offering.totalAmountSold, 25_000_000)
        XCTAssertEqual(offering.totalRemaining, 25_000_000)
    }

    func testFormDParserMinimalFields() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <edgarSubmission>
            <primaryIssuer>
                <entityName>Minimal LLC</entityName>
                <cik>1234567</cik>
            </primaryIssuer>
        </edgarSubmission>
        """

        let offering = try FormDParser.parse(data: xml.data(using: .utf8)!)

        XCTAssertEqual(offering.entityName, "Minimal LLC")
        XCTAssertEqual(offering.entityCik, 1234567)
        XCTAssertNil(offering.entityType)
        XCTAssertNil(offering.industryGroup)
        XCTAssertTrue(offering.federalExemptions.isEmpty)
        XCTAssertNil(offering.totalOfferingAmount)
    }

    // MARK: - Facade

    func testFacadeProxyFilings() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let filings = try await edgar.proxyFilings(cik: 320193, limit: 2)
        XCTAssertFalse(filings.isEmpty)
    }

    func testFacadeOwnershipFilings() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let filings = try await edgar.ownershipFilings(cik: 320193, limit: 5)
        // May be empty — that's fine, just verify it doesn't throw
    }

    func testFacadeRegistrationFilings() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let filings = try await edgar.registrationFilings(cik: 1318605, limit: 3)
        // May be empty for recent filings
    }
}
