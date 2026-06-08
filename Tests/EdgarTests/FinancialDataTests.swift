import XCTest
@testable import Edgar

final class FinancialDataTests: XCTestCase {

    let client = EdgarClient(userAgent: "EdgarToolsTests/1.0 (test@example.com)")

    // MARK: - Company Facts

    func testCompanyFactsApple() async throws {
        // Apple CIK: 320193
        let facts = try await client.getCompanyFacts(cik: 320193)

        XCTAssertEqual(facts.cik, 320193)
        XCTAssertFalse(facts.entityName.isEmpty)
        XCTAssertFalse(facts.usGaap.isEmpty, "Should have us-gaap concepts")
        XCTAssertFalse(facts.dei.isEmpty, "Should have dei concepts")

        // Apple should have revenue data
        let conceptNames = facts.conceptNames()
        XCTAssertTrue(conceptNames.count > 100, "Apple should have many concepts, got \(conceptNames.count)")
    }

    func testCompanyFactsLatestValue() async throws {
        let facts = try await client.getCompanyFacts(cik: 320193) // Apple

        // Apple has reported net income
        let netIncome = facts.latestValue("NetIncomeLoss")
        XCTAssertNotNil(netIncome, "Apple should have NetIncomeLoss")
        XCTAssertTrue(netIncome! > 0, "Apple net income should be positive")
    }

    func testCompanyFactsConceptLookup() async throws {
        let facts = try await client.getCompanyFacts(cik: 320193)

        let revenue = facts.concept("Revenues")
            ?? facts.concept("RevenueFromContractWithCustomerExcludingAssessedTax")

        XCTAssertNotNil(revenue, "Apple should have a revenue concept")

        if let rev = revenue {
            XCTAssertFalse(rev.annualValues.isEmpty, "Should have annual revenue values")
        }
    }

    func testCompanyFactsAnnualVsQuarterly() async throws {
        let facts = try await client.getCompanyFacts(cik: 320193)

        // Find a concept that has both annual and quarterly
        if let assets = facts.concept("Assets") {
            let annual = assets.annualValues
            let quarterly = assets.quarterlyValues
            XCTAssertFalse(annual.isEmpty, "Should have annual Assets values")
            // Quarterly may or may not exist for balance sheet items
            // But annual definitely should
            XCTAssertTrue(annual.first!.val > 0)
        }
    }

    // MARK: - Company Concept

    func testCompanyConceptRevenue() async throws {
        // Microsoft CIK: 789019
        let concept = try await client.getCompanyConcept(
            cik: 789019,
            concept: "Revenues"
        )

        XCTAssertEqual(concept.cik, 789019)
        XCTAssertEqual(concept.tag, "Revenues")
        XCTAssertFalse(concept.entityName.isEmpty)
        XCTAssertFalse(concept.usdValues.isEmpty, "Should have USD revenue values")

        // Verify values are sorted descending by date
        let values = concept.usdValues
        if values.count >= 2 {
            XCTAssertTrue(values[0].end >= values[1].end, "Should be sorted by date descending")
        }
    }

    func testCompanyConceptAssets() async throws {
        let concept = try await client.getCompanyConcept(
            cik: 320193, // Apple
            concept: "Assets"
        )

        XCTAssertEqual(concept.tag, "Assets")
        XCTAssertFalse(concept.usdValues.isEmpty)

        // Apple's total assets should be > $100B
        if let latest = concept.usdValues.first {
            XCTAssertTrue(latest.val > 100_000_000_000, "Apple assets should be > $100B")
        }
    }

    func testCompanyConceptInvalidConcept() async throws {
        do {
            _ = try await client.getCompanyConcept(
                cik: 320193,
                concept: "TotallyFakeConceptThatDoesNotExist"
            )
            XCTFail("Should throw for invalid concept")
        } catch {
            // Expected — 404 or similar
        }
    }

    // MARK: - Frames

    func testFrameRevenueAnnual() async throws {
        let frame = try await client.getFrame(
            concept: "Revenues",
            period: "CY2023"
        )

        XCTAssertEqual(frame.tag, "Revenues")
        XCTAssertEqual(frame.ccp, "CY2023")
        XCTAssertTrue(frame.pts > 0, "Should have data points")
        XCTAssertFalse(frame.data.isEmpty, "Should have company entries")

        // Top companies by revenue
        let top = frame.topCompanies(5)
        XCTAssertEqual(top.count, 5)
        XCTAssertTrue(top[0].val >= top[1].val, "Should be sorted by value")
    }

    func testFrameFindCompany() async throws {
        let frame = try await client.getFrame(
            concept: "Assets",
            period: "CY2023Q4I" // instantaneous for balance sheet
        )

        // Try to find Apple (CIK 320193) in the frame
        let apple = frame.entry(forCIK: 320193)
        // Apple may or may not be in this exact period frame
        if let a = apple {
            XCTAssertEqual(a.cik, 320193)
            XCTAssertTrue(a.val > 0)
        }
    }

    func testFrameQuarterly() async throws {
        let frame = try await client.getFrame(
            concept: "Revenues",
            period: "CY2023Q3"
        )

        XCTAssertTrue(frame.pts > 0)
        XCTAssertFalse(frame.data.isEmpty)
    }

    // MARK: - High-level Facade

    func testFacadeCompanyFacts() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let facts = try await edgar.companyFacts(cik: 789019) // Microsoft
        XCTAssertEqual(facts.cik, 789019)
        XCTAssertFalse(facts.usGaap.isEmpty)
    }

    func testFacadeCompanyConcept() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let concept = try await edgar.companyConcept(cik: 320193, concept: "Assets")
        XCTAssertEqual(concept.tag, "Assets")
        XCTAssertFalse(concept.usdValues.isEmpty)
    }

    func testFacadeFrame() async throws {
        let edgar = Edgar(userAgent: "EdgarToolsTests/1.0 (test@example.com)")
        let frame = try await edgar.frame(concept: "Revenues", period: "CY2023")
        XCTAssertTrue(frame.pts > 0)
    }
}
