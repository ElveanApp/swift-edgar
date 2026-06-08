import Foundation

/// Maps CUSIP identifiers to ticker symbols via the OpenFIGI API.
///
/// Without an API key: 10 CUSIPs per request, ~5 requests/minute.
/// With an API key: 100 per request, ~25 requests/minute.
public actor CUSIPMapper {

    private var cache: [String: String] = [:]
    private let session: URLSession
    private let apiKey: String?

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
    }

    /// Resolve CUSIPs to ticker symbols. Returns [CUSIP: ticker] for successful lookups.
    public func resolve(_ cusips: [String]) async -> [String: String] {
        let unique = Array(Set(cusips))
        var results: [String: String] = [:]
        var toResolve: [String] = []

        for cusip in unique {
            if let cached = cache[cusip] {
                results[cusip] = cached
            } else {
                toResolve.append(cusip)
            }
        }

        guard !toResolve.isEmpty else { return results }

        let batchSize = apiKey != nil ? 100 : 10
        for batch in toResolve.chunked(into: batchSize) {
            do {
                let resolved = try await lookupBatch(batch)
                for (cusip, ticker) in resolved {
                    results[cusip] = ticker
                    cache[cusip] = ticker
                }
            } catch {
                // OpenFIGI failures are non-fatal; holdings just won't have tickers
                continue
            }
        }

        return results
    }

    /// Resolve tickers for a list of holdings, returning a new array with tickers filled in.
    public func resolveHoldings(_ holdings: [Holding]) async -> [Holding] {
        let cusips = holdings.map(\.cusip)
        let mapping = await resolve(cusips)

        return holdings.map { holding in
            var h = holding
            h.ticker = mapping[holding.cusip]
            return h
        }
    }

    // MARK: - Private

    private func lookupBatch(_ cusips: [String]) async throws -> [String: String] {
        guard let url = URL(string: "https://api.openfigi.com/v3/mapping") else {
            return [:]
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-OPENFIGI-APIKEY")
        }

        let body = cusips.map { FIGIRequest(idType: "ID_CUSIP", idValue: $0) }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await session.data(for: request)
        let responses = try JSONDecoder().decode([FIGIResponseItem].self, from: data)

        var results: [String: String] = [:]
        for (i, item) in responses.enumerated() where i < cusips.count {
            if let ticker = item.data?.first?.ticker {
                results[cusips[i]] = ticker
            }
        }

        return results
    }
}

// MARK: - OpenFIGI API Models

private struct FIGIRequest: Codable {
    let idType: String
    let idValue: String
}

private struct FIGIResponseItem: Codable {
    let data: [FIGIResult]?
    let warning: String?
    let error: String?
}

private struct FIGIResult: Codable {
    let ticker: String?
    let name: String?
    let exchCode: String?
    let securityType: String?
}

// MARK: - Array Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
