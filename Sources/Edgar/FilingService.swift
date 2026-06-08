import Foundation

extension EdgarClient {

    /// Get recent filings for a company, optionally filtered by form type.
    public func getFilings(cik: Int, form: String? = nil) async throws -> [Filing] {
        let url = try Self.submissionsURL(cik: cik)

        let data = try await getData(from: url)
        let response = try JSONDecoder().decode(SubmissionsResponse.self, from: data)
        return Self.parseRecentFilings(response.filings.recent, form: form)
    }

    /// Parse parallel arrays from a submissions response into Filing objects.
    static func parseRecentFilings(_ recent: SubmissionsResponse.RecentFilings, form: String?) -> [Filing] {
        let count = min(
            recent.accessionNumber.count,
            recent.filingDate.count,
            recent.reportDate.count,
            recent.form.count,
            recent.primaryDocument.count,
            recent.primaryDocDescription.count
        )

        var filings: [Filing] = []
        for i in 0..<count {
            let filing = Filing(
                accessionNumber: recent.accessionNumber[i],
                filingDate: recent.filingDate[i],
                reportDate: recent.reportDate[i],
                form: recent.form[i],
                primaryDocument: recent.primaryDocument[i],
                primaryDocDescription: recent.primaryDocDescription[i]
            )
            if let form {
                if filing.form == form || filing.form == "\(form)/A" {
                    filings.append(filing)
                }
            } else {
                filings.append(filing)
            }
        }
        return filings
    }

    /// Get the most recent 13F-HR filing for a company.
    public func getLatest13F(cik: Int) async throws -> Filing {
        let filings = try await getFilings(cik: cik, form: "13F-HR")
        guard let latest = filings.first else {
            throw EdgarError.noFilingsFound(cik: cik, form: "13F-HR")
        }
        return latest
    }

    /// Find the URL of the 13F information table XML document within a filing.
    public func findInformationTableURL(cik: Int, filing: Filing) async throws -> URL {
        let dirURL = try filing.directoryURL(cik: cik)
        let indexURL = dirURL.appendingPathComponent("index.json")

        let data = try await getData(from: indexURL)

        let index: FilingIndex
        do {
            index = try JSONDecoder().decode(FilingIndex.self, from: data)
        } catch {
            return try filing.primaryDocumentURL(cik: cik)
        }

        // primaryDocument may include a subdirectory (e.g. "xslForm13F_X02/primary_doc.xml")
        // but index items are flat filenames — compare against the filename component only
        let primaryFilename = (filing.primaryDocument as NSString).lastPathComponent

        let xmlFiles = index.directory.item.filter { item in
            let lower = item.name.lowercased()
            return lower.hasSuffix(".xml") && item.name != primaryFilename
        }

        // Prefer files with "infotable" or "information" in the name
        if let infoTable = xmlFiles.first(where: {
            let lower = $0.name.lowercased()
            return lower.contains("infotable") || lower.contains("information")
        }) {
            return dirURL.appendingPathComponent(infoTable.name)
        }

        // Fall back to the largest non-primary XML (info table is always bigger than the cover)
        if let largest = xmlFiles
            .sorted(by: { Int($0.size ?? "0") ?? 0 > Int($1.size ?? "0") ?? 0 })
            .first {
            return dirURL.appendingPathComponent(largest.name)
        }

        return try filing.primaryDocumentURL(cik: cik)
    }

    /// Download and parse a 13F filing's holdings.
    public func getHoldings(cik: Int, filing: Filing) async throws -> [Holding] {
        let url = try await findInformationTableURL(cik: cik, filing: filing)
        let data = try await getRawData(from: url)
        return try ThirteenFParser.parse(data: data)
    }
}
