import Foundation

// MARK: - XBRL Financial Data Models

/// All financial facts for a company from the XBRL Company Facts API.
/// Contains every concept ever reported across all filings.
public struct CompanyFacts: Codable, Sendable {
    public let cik: Int
    public let entityName: String
    public let facts: [String: [String: FactConcept]] // taxonomy → concept → data

    /// Get all concepts in the us-gaap taxonomy.
    public var usGaap: [String: FactConcept] { facts["us-gaap"] ?? [:] }

    /// Get all concepts in the dei taxonomy.
    public var dei: [String: FactConcept] { facts["dei"] ?? [:] }

    /// Look up a specific concept (e.g., "Revenue", "NetIncomeLoss").
    public func concept(_ name: String, taxonomy: String = "us-gaap") -> FactConcept? {
        facts[taxonomy]?[name]
    }

    /// Get the most recent value for a concept.
    public func latestValue(_ conceptName: String, taxonomy: String = "us-gaap", unit: String = "USD") -> Double? {
        guard let concept = facts[taxonomy]?[conceptName],
              let values = concept.units[unit] else { return nil }
        return values.filter { $0.form == "10-K" || $0.form == "10-Q" }
            .sorted { $0.end > $1.end }
            .first?.val
    }

    /// Get all available concept names for a taxonomy.
    public func conceptNames(taxonomy: String = "us-gaap") -> [String] {
        Array(facts[taxonomy]?.keys ?? [:].keys).sorted()
    }
}

/// A single financial concept (e.g., "Revenue") with all its historical values.
public struct FactConcept: Codable, Sendable {
    public let label: String?
    public let description: String?
    public let units: [String: [FactValue]] // unit (USD, shares, pure) → values

    /// Get all values in USD, sorted by date descending.
    public var usdValues: [FactValue] {
        (units["USD"] ?? []).sorted { $0.end > $1.end }
    }

    /// Get annual values only (from 10-K filings).
    public var annualValues: [FactValue] {
        (units["USD"] ?? []).filter { $0.form == "10-K" && $0.fp == "FY" }
            .sorted { $0.end > $1.end }
    }

    /// Get quarterly values only (from 10-Q filings).
    public var quarterlyValues: [FactValue] {
        (units["USD"] ?? [])
            .filter { $0.form == "10-Q" }
            .sorted { $0.end > $1.end }
    }
}

/// A single data point for a financial concept at a specific point in time.
public struct FactValue: Codable, Sendable {
    public let start: String?
    public let end: String
    public let val: Double
    public let accn: String
    public let fy: Int?
    public let fp: String?   // FY, Q1, Q2, Q3, Q4
    public let form: String  // 10-K, 10-Q, 8-K
    public let filed: String
    public let frame: String?
}

/// Historical values for a single concept across all periods.
/// From the Company Concept API.
public struct CompanyConcept: Codable, Sendable {
    public let cik: Int
    public let taxonomy: String
    public let tag: String
    public let label: String
    public let description: String
    public let entityName: String
    public let units: [String: [FactValue]]

    /// All USD values sorted by date.
    public var usdValues: [FactValue] {
        (units["USD"] ?? []).sorted { $0.end > $1.end }
    }
}

/// Cross-company data for a single concept in a single period.
/// From the Frames API.
public struct FinancialFrame: Codable, Sendable {
    public let taxonomy: String
    public let tag: String
    public let ccp: String   // calendar period (CY2023, CY2023Q1, etc.)
    public let uom: String   // unit of measure
    public let label: String
    public let description: String
    public let pts: Int       // number of data points
    public let data: [FrameEntry]

    /// Get top N companies by value.
    public func topCompanies(_ count: Int = 10) -> [FrameEntry] {
        Array(data.sorted { $0.val > $1.val }.prefix(count))
    }

    /// Find a specific company's entry.
    public func entry(forCIK cik: Int) -> FrameEntry? {
        data.first { $0.cik == cik }
    }
}

/// A single company's data point within a financial frame.
public struct FrameEntry: Codable, Sendable {
    public let accn: String
    public let cik: Int
    public let entityName: String
    public let loc: String
    public let end: String
    public let val: Double
}

// MARK: - Financial Service

extension EdgarClient {

    /// Get all financial facts for a company (all concepts, all periods).
    /// This is the richest single API call — returns everything from every filing.
    public func getCompanyFacts(cik: Int) async throws -> CompanyFacts {
        let padded = Self.paddedCIK(cik)
        guard let url = URL(string: "\(Self.baseURL)/api/xbrl/companyfacts/\(padded).json") else {
            throw EdgarError.invalidURL("companyfacts for CIK \(cik)")
        }
        let data = try await getData(from: url)
        return try JSONDecoder().decode(CompanyFacts.self, from: data)
    }

    /// Get historical values for a single financial concept.
    /// - Parameters:
    ///   - cik: Company CIK.
    ///   - taxonomy: XBRL taxonomy (default: "us-gaap").
    ///   - concept: Concept name (e.g., "Revenue", "NetIncomeLoss", "Assets").
    public func getCompanyConcept(cik: Int, taxonomy: String = "us-gaap", concept: String) async throws -> CompanyConcept {
        let padded = Self.paddedCIK(cik)
        guard let url = URL(string: "\(Self.baseURL)/api/xbrl/companyconcept/\(padded)/\(taxonomy)/\(concept).json") else {
            throw EdgarError.invalidURL("companyconcept \(concept) for CIK \(cik)")
        }
        let data = try await getData(from: url)
        return try JSONDecoder().decode(CompanyConcept.self, from: data)
    }

    /// Get cross-company data for a concept in a specific period.
    /// Useful for comparing all companies on a single metric.
    /// - Parameters:
    ///   - taxonomy: XBRL taxonomy (default: "us-gaap").
    ///   - concept: Concept name.
    ///   - unit: Unit of measure (default: "USD").
    ///   - period: Calendar period (e.g., "CY2023", "CY2023Q1").
    public func getFrame(taxonomy: String = "us-gaap", concept: String, unit: String = "USD", period: String) async throws -> FinancialFrame {
        guard let url = URL(string: "\(Self.baseURL)/api/xbrl/frames/\(taxonomy)/\(concept)/\(unit)/\(period).json") else {
            throw EdgarError.invalidURL("frame \(concept)/\(unit)/\(period)")
        }
        let data = try await getData(from: url)
        return try JSONDecoder().decode(FinancialFrame.self, from: data)
    }
}
