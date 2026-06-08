import Foundation

/// SEC EDGAR HTTP client with built-in rate limiting.
///
/// The SEC requires a descriptive User-Agent header and enforces a 10 req/sec limit.
public actor EdgarClient {

    static let baseURL = "https://data.sec.gov"
    static let archivesBaseURL = "https://www.sec.gov/Archives/edgar/data"
    static let tickersURL = "https://www.sec.gov/files/company_tickers.json"
    static let searchURL = "https://efts.sec.gov/LATEST/search-index"

    /// Zero-padded CIK string for SEC API URLs.
    static func paddedCIK(_ cik: Int) -> String {
        String(format: "CIK%010d", cik)
    }

    /// Build the submissions URL for a given CIK.
    static func submissionsURL(cik: Int) throws -> URL {
        let str = "\(baseURL)/submissions/\(paddedCIK(cik)).json"
        guard let url = URL(string: str) else { throw EdgarError.invalidURL(str) }
        return url
    }

    private let session: URLSession
    private var lastRequestTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.12 // ~8 req/sec (safe margin under 10)

    // Cached company tickers (large file, downloaded once)
    private var tickerCache: [String: CompanyTicker]?

    public init(userAgent: String = "EdgarTools/1.0 (dev@example.com)") {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept-Encoding": "gzip, deflate",
        ]
        self.session = URLSession(configuration: config)
    }

    /// GET request expecting JSON response.
    func getData(from url: URL) async throws -> Data {
        try await rateLimit()

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, url: url)
        return data
    }

    /// GET request for raw data (XML, etc.).
    func getRawData(from url: URL) async throws -> Data {
        try await rateLimit()

        let (data, response) = try await session.data(from: url)
        try validateResponse(response, url: url)
        return data
    }

    // MARK: - Ticker Cache

    func loadCompanyTickers() async throws -> [String: CompanyTicker] {
        if let cached = tickerCache { return cached }

        guard let url = URL(string: Self.tickersURL) else {
            throw EdgarError.invalidURL(Self.tickersURL)
        }

        let data = try await getData(from: url)
        let tickers = try JSONDecoder().decode([String: CompanyTicker].self, from: data)
        tickerCache = tickers
        return tickers
    }

    // MARK: - Private

    private func rateLimit() async throws {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        lastRequestTime = Date()
    }

    private func validateResponse(_ response: URLResponse, url: URL) throws {
        guard let http = response as? HTTPURLResponse else {
            throw EdgarError.httpError(statusCode: -1, url: url.absoluteString)
        }
        switch http.statusCode {
        case 200...299:
            return
        case 429:
            throw EdgarError.rateLimited
        default:
            throw EdgarError.httpError(statusCode: http.statusCode, url: url.absoluteString)
        }
    }
}
