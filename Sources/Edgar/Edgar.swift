import Foundation

/// High-level API for SEC EDGAR data — filings, financials, insider trading, fund holdings, and more.
///
/// Usage:
/// ```swift
/// let edgar = Edgar()
///
/// // 13F portfolio
/// let portfolio = try await edgar.latestPortfolio(cik: 1067983)
///
/// // Financial data
/// let facts = try await edgar.companyFacts(cik: 320193) // Apple
/// let revenue = facts.latestValue("Revenues")
///
/// // Insider trades
/// let trades = try await edgar.recentInsiderTrades(cik: 320193)
///
/// // 8-K events
/// let events = try await edgar.eightKFilings(cik: 320193)
///
/// // Fund holdings
/// let fund = try await edgar.latestFundPortfolio(cik: 886982) // Vanguard 500
/// ```
public struct Edgar: Sendable {

    private let client: EdgarClient
    private let cusipMapper: CUSIPMapper

    /// Create a new Edgar instance.
    /// - Parameters:
    ///   - userAgent: Required by SEC EDGAR. Format: "AppName/Version (email@example.com)"
    ///   - openFIGIKey: Optional API key for higher OpenFIGI rate limits (CUSIP→ticker resolution).
    public init(
        userAgent: String = "EdgarTools/1.0 (dev@example.com)",
        openFIGIKey: String? = nil
    ) {
        self.client = EdgarClient(userAgent: userAgent)
        self.cusipMapper = CUSIPMapper(apiKey: openFIGIKey)
    }

    // MARK: - Company Search

    /// Look up a company by CIK number.
    public func company(cik: Int) async throws -> Company {
        try await client.getCompany(cik: cik)
    }

    /// Search for a company by ticker symbol (exact match).
    public func company(ticker: String) async throws -> CompanySearchResult? {
        try await client.searchByTicker(ticker)
    }

    /// Search for companies by name (substring match against SEC company list).
    public func searchCompanies(_ query: String) async throws -> [CompanySearchResult] {
        try await client.searchByName(query)
    }

    /// Search for 13F filers by name via EDGAR full-text search.
    public func searchFilers(_ query: String) async throws -> [CompanySearchResult] {
        try await client.searchFilers(query)
    }

    // MARK: - Filings

    /// Get recent 13F-HR filings for a company.
    public func filings(cik: Int) async throws -> [Filing] {
        try await client.getFilings(cik: cik, form: "13F-HR")
    }

    /// Get the most recent 13F-HR filing.
    public func latestFiling(cik: Int) async throws -> Filing {
        try await client.getLatest13F(cik: cik)
    }

    /// Get all filings of any type across full history (paginated).
    public func allFilings(cik: Int, form: String? = nil, limit: Int? = nil) async throws -> [Filing] {
        try await client.getAllFilings(cik: cik, form: form, limit: limit)
    }

    // MARK: - Portfolio (13F)

    /// Get the portfolio from a specific 13F filing.
    public func portfolio(cik: Int, filing: Filing, resolveTickers: Bool = true) async throws -> Portfolio {
        let company = try await client.getCompany(cik: cik)
        var holdings = try await client.getHoldings(cik: cik, filing: filing)

        if resolveTickers {
            holdings = await cusipMapper.resolveHoldings(holdings)
        }

        return Portfolio(company: company, filing: filing, holdings: holdings)
    }

    /// Get the latest 13F portfolio for a company.
    public func latestPortfolio(cik: Int, resolveTickers: Bool = true) async throws -> Portfolio {
        let filing = try await client.getLatest13F(cik: cik)
        return try await portfolio(cik: cik, filing: filing, resolveTickers: resolveTickers)
    }

    /// Compare the two most recent 13F portfolios quarter-over-quarter.
    public func compareQuarters(cik: Int, resolveTickers: Bool = true) async throws -> PortfolioComparison {
        let allFilings = try await client.getFilings(cik: cik, form: "13F-HR")
        guard allFilings.count >= 2 else {
            throw EdgarError.noFilingsFound(cik: cik, form: "13F-HR (need at least 2 quarters)")
        }

        async let current = portfolio(cik: cik, filing: allFilings[0], resolveTickers: resolveTickers)
        async let previous = portfolio(cik: cik, filing: allFilings[1], resolveTickers: resolveTickers)

        return try await PortfolioComparison.compare(current: current, previous: previous)
    }

    // MARK: - XBRL Financial Data

    /// Get all financial facts for a company (all concepts, all periods).
    public func companyFacts(cik: Int) async throws -> CompanyFacts {
        try await client.getCompanyFacts(cik: cik)
    }

    /// Get historical values for a single financial concept (e.g., "Revenue", "NetIncomeLoss").
    public func companyConcept(cik: Int, taxonomy: String = "us-gaap", concept: String) async throws -> CompanyConcept {
        try await client.getCompanyConcept(cik: cik, taxonomy: taxonomy, concept: concept)
    }

    /// Get cross-company data for a concept in a specific period (e.g., "CY2023").
    public func frame(taxonomy: String = "us-gaap", concept: String, unit: String = "USD", period: String) async throws -> FinancialFrame {
        try await client.getFrame(taxonomy: taxonomy, concept: concept, unit: unit, period: period)
    }

    // MARK: - Insider Trading (Form 4)

    /// Get recent Form 4 insider trading filings.
    public func insiderFilings(cik: Int, limit: Int = 20) async throws -> [Filing] {
        try await client.getInsiderFilings(cik: cik, limit: limit)
    }

    /// Parse a specific Form 4 filing into structured data.
    public func parseInsiderFiling(cik: Int, filing: Filing) async throws -> InsiderReport {
        try await client.parseInsiderFiling(cik: cik, filing: filing)
    }

    /// Get recent insider trades parsed into structured reports.
    public func recentInsiderTrades(cik: Int, limit: Int = 10) async throws -> [InsiderReport] {
        try await client.getRecentInsiderTrades(cik: cik, limit: limit)
    }

    // MARK: - 8-K Events

    /// Get recent 8-K filings with parsed event item codes.
    public func eightKFilings(cik: Int, limit: Int = 20) async throws -> [EightKFiling] {
        try await client.getEightKFilings(cik: cik, limit: limit)
    }

    // MARK: - Fund Holdings (N-PORT)

    /// Get recent N-PORT filings for a fund.
    public func fundFilings(cik: Int, limit: Int = 10) async throws -> [Filing] {
        try await client.getFundFilings(cik: cik, limit: limit)
    }

    /// Parse an N-PORT filing into structured fund portfolio data.
    public func parseFundFiling(cik: Int, filing: Filing) async throws -> FundPortfolio {
        try await client.parseFundFiling(cik: cik, filing: filing)
    }

    /// Get the latest fund portfolio from N-PORT filings.
    public func latestFundPortfolio(cik: Int) async throws -> FundPortfolio {
        try await client.getLatestFundPortfolio(cik: cik)
    }

    // MARK: - Ownership & Governance

    /// Get beneficial ownership filings (Schedule 13D/G).
    public func ownershipFilings(cik: Int, limit: Int = 10) async throws -> [Filing] {
        try await client.getOwnershipFilings(cik: cik, limit: limit)
    }

    /// Get proxy statement filings (DEF 14A).
    public func proxyFilings(cik: Int, limit: Int = 5) async throws -> [Filing] {
        try await client.getProxyFilings(cik: cik, limit: limit)
    }

    /// Get registration statement filings (S-1, S-3, S-4).
    public func registrationFilings(cik: Int, limit: Int = 5) async throws -> [Filing] {
        try await client.getRegistrationFilings(cik: cik, limit: limit)
    }

    /// Get Form D (private offering) filings.
    public func formDFilings(cik: Int, limit: Int = 10) async throws -> [Filing] {
        try await client.getFormDFilings(cik: cik, limit: limit)
    }

    // MARK: - Filing Text

    /// Get raw HTML of a filing's primary document.
    public func filingHTML(cik: Int, filing: Filing) async throws -> String {
        try await client.getFilingHTML(cik: cik, filing: filing)
    }

    /// Get plain text of a filing (HTML tags stripped).
    public func filingText(cik: Int, filing: Filing) async throws -> String {
        try await client.getFilingText(cik: cik, filing: filing)
    }
}
