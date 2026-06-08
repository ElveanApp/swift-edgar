import Foundation

// MARK: - Public Models

public struct Filing: Codable, Sendable {
    public let accessionNumber: String
    public let filingDate: String
    public let reportDate: String
    public let form: String
    public let primaryDocument: String
    public let primaryDocDescription: String

    /// Accession number with dashes removed (for URL paths).
    public var accessionNumberClean: String {
        accessionNumber.replacingOccurrences(of: "-", with: "")
    }

    /// Base URL for all documents in this filing.
    public func directoryURL(cik: Int) throws -> URL {
        let str = "\(EdgarClient.archivesBaseURL)/\(cik)/\(accessionNumberClean)/"
        guard let url = URL(string: str) else {
            throw EdgarError.invalidURL(str)
        }
        return url
    }

    /// URL for the primary document.
    public func primaryDocumentURL(cik: Int) throws -> URL {
        try directoryURL(cik: cik).appendingPathComponent(primaryDocument)
    }
}

// MARK: - Internal Models

/// Response from filing index.json
struct FilingIndex: Codable {
    let directory: FilingDirectory
}

struct FilingDirectory: Codable {
    let item: [FilingDirectoryItem]
    let name: String
}

struct FilingDirectoryItem: Codable {
    let name: String
    let lastModified: String?
    let type: String?
    let href: String?
    let size: String?

    enum CodingKeys: String, CodingKey {
        case name
        case lastModified = "last-modified"
        case type
        case href
        case size
    }
}
