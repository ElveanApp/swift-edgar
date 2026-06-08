import Foundation

extension EdgarClient {

    /// Look up a company by CIK number. Returns full company details.
    public func getCompany(cik: Int) async throws -> Company {
        let url = try Self.submissionsURL(cik: cik)

        let data = try await getData(from: url)

        let response: SubmissionsResponse
        do {
            response = try JSONDecoder().decode(SubmissionsResponse.self, from: data)
        } catch {
            throw EdgarError.decodingError("Failed to decode submissions for CIK \(cik): \(error.localizedDescription)")
        }

        return Company(
            cik: Int(response.cik) ?? cik,
            name: response.name,
            tickers: response.tickers ?? [],
            exchanges: response.exchanges ?? [],
            sic: response.sic,
            sicDescription: response.sicDescription,
            category: response.category,
            fiscalYearEnd: response.fiscalYearEnd,
            stateOfIncorporation: response.stateOfIncorporation,
            entityType: response.entityType
        )
    }

    /// Search for a company by ticker symbol (exact match).
    public func searchByTicker(_ ticker: String) async throws -> CompanySearchResult? {
        let tickers = try await loadCompanyTickers()
        let upper = ticker.uppercased()
        return tickers.values
            .first { $0.ticker.uppercased() == upper }
            .map { CompanySearchResult(cik: $0.cik_str, name: $0.title, ticker: $0.ticker) }
    }

    /// Search for companies by name (substring match against SEC company list).
    public func searchByName(_ query: String) async throws -> [CompanySearchResult] {
        let tickers = try await loadCompanyTickers()
        let lower = query.lowercased()

        return tickers.values
            .filter { $0.title.lowercased().contains(lower) }
            .sorted { $0.title.count < $1.title.count } // prefer shorter (more exact) matches
            .prefix(20)
            .map { CompanySearchResult(cik: $0.cik_str, name: $0.title, ticker: $0.ticker) }
    }

    /// Search EDGAR full-text search for 13F filers by name.
    /// This can find investment managers that don't have tickers.
    public func searchFilers(_ query: String, form: String = "13F-HR") async throws -> [CompanySearchResult] {
        guard var components = URLComponents(string: Self.searchURL) else {
            throw EdgarError.invalidURL(Self.searchURL)
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: "\"\(query)\""),
            URLQueryItem(name: "forms", value: form),
        ]

        guard let url = components.url else {
            throw EdgarError.invalidURL(Self.searchURL)
        }

        let data = try await getData(from: url)

        let response: EFTSResponse
        do {
            response = try JSONDecoder().decode(EFTSResponse.self, from: data)
        } catch {
            // EFTS format may change; return empty results instead of crashing
            return []
        }

        var seen = Set<Int>()
        var results: [CompanySearchResult] = []

        for hit in response.hits.hits {
            let source = hit._source
            guard let cikStr = source.ciks?.first,
                  let cik = Int(cikStr),
                  cik > 0, !seen.contains(cik) else { continue }
            seen.insert(cik)

            // Extract clean name from display_names like "SOROS FUND MANAGEMENT LLC  (CIK 0001029160)"
            let displayName = source.display_names?.first ?? "Unknown"
            let name = displayName.replacingOccurrences(
                of: "\\s*\\(CIK \\d+\\)$", with: "", options: .regularExpression
            ).trimmingCharacters(in: .whitespaces)

            results.append(CompanySearchResult(
                cik: cik,
                name: name,
                ticker: nil
            ))
        }

        return results
    }
}
