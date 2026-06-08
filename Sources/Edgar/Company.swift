import Foundation

// MARK: - Public Models

public struct Company: Codable, Sendable {
    public let cik: Int
    public let name: String
    public let tickers: [String]
    public let exchanges: [String]
    public let sic: String?
    public let sicDescription: String?
    public let category: String?
    public let fiscalYearEnd: String?
    public let stateOfIncorporation: String?
    public let entityType: String?

    public init(cik: Int, name: String, tickers: [String] = [], exchanges: [String] = [],
                sic: String? = nil, sicDescription: String? = nil, category: String? = nil,
                fiscalYearEnd: String? = nil, stateOfIncorporation: String? = nil,
                entityType: String? = nil) {
        self.cik = cik
        self.name = name
        self.tickers = tickers
        self.exchanges = exchanges
        self.sic = sic
        self.sicDescription = sicDescription
        self.category = category
        self.fiscalYearEnd = fiscalYearEnd
        self.stateOfIncorporation = stateOfIncorporation
        self.entityType = entityType
    }
}

public struct CompanySearchResult: Sendable {
    public let cik: Int
    public let name: String
    public let ticker: String?
}

// MARK: - Internal API Response Models

/// Response from https://data.sec.gov/submissions/CIK{padded}.json
struct SubmissionsResponse: Codable {
    let cik: String
    let name: String
    let tickers: [String]?
    let exchanges: [String]?
    let sic: String?
    let sicDescription: String?
    let category: String?
    let fiscalYearEnd: String?
    let stateOfIncorporation: String?
    let entityType: String?
    let filings: FilingsContainer

    struct FilingsContainer: Codable {
        let recent: RecentFilings
        let files: [FilingsFile]?
    }

    struct RecentFilings: Codable {
        let accessionNumber: [String]
        let filingDate: [String]
        let reportDate: [String]
        let form: [String]
        let primaryDocument: [String]
        let primaryDocDescription: [String]
        let items: [String]?  // present in 8-K context
    }

    struct FilingsFile: Codable {
        let name: String
        let filingCount: Int
        let filingFrom: String
        let filingTo: String
    }
}

/// Entry from https://www.sec.gov/files/company_tickers.json
struct CompanyTicker: Codable {
    let cik_str: Int
    let ticker: String
    let title: String
}

/// Response from EDGAR full-text search (efts.sec.gov)
struct EFTSResponse: Codable {
    let hits: EFTSHits
}

struct EFTSHits: Codable {
    let hits: [EFTSHit]
    let total: EFTSTotal?
}

struct EFTSTotal: Codable {
    let value: Int
}

struct EFTSHit: Codable {
    let _source: EFTSSource
}

struct EFTSSource: Codable {
    let ciks: [String]?
    let display_names: [String]?
    let file_date: String?
    let form: String?
}
