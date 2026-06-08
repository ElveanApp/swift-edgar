import Foundation

public enum EdgarError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case httpError(statusCode: Int, url: String)
    case rateLimited
    case decodingError(String)
    case companyNotFound(String)
    case noFilingsFound(cik: Int, form: String)
    case informationTableNotFound(accessionNumber: String)
    case xmlParsingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            "Invalid URL: \(url)"
        case .httpError(let code, let url):
            "HTTP \(code) for \(url)"
        case .rateLimited:
            "SEC EDGAR rate limit exceeded (max 10 requests/second)"
        case .decodingError(let detail):
            "Failed to decode response: \(detail)"
        case .companyNotFound(let query):
            "No company found for: \(query)"
        case .noFilingsFound(let cik, let form):
            "No \(form) filings found for CIK \(cik)"
        case .informationTableNotFound(let accession):
            "Information table not found in filing \(accession)"
        case .xmlParsingError(let detail):
            "XML parsing error: \(detail)"
        }
    }
}
