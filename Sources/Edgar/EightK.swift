import Foundation

// MARK: - 8-K Event Models

public struct EightKFiling: Sendable {
    public let filing: Filing
    public let items: [EightKItem]
}

public enum EightKItem: Sendable {
    case materialAgreement                     // 1.01
    case terminationOfAgreement                // 1.02
    case bankruptcy                            // 1.03
    case minesSafetyReport                     // 1.04
    case acquisitionOrDisposition              // 2.01
    case resultsOfOperations                   // 2.02
    case directFinancialObligation             // 2.03
    case triggeringEvents                      // 2.04
    case costsFromExitActivities               // 2.05
    case materialImpairments                   // 2.06
    case noticeOfDelisting                     // 3.01
    case unregisteredSalesOfEquity             // 3.02
    case materialModToRightsOfHolders          // 3.03
    case changeInCertifyingAccountant          // 4.01
    case nonRelianceOnFinancials               // 4.02
    case changeInControlOfRegistrant           // 5.01
    case departureOfDirectorsOrOfficers        // 5.02
    case amendmentsToArticles                  // 5.03
    case temporarySuspensionOfTrading          // 5.04
    case amendmentToCodeOfEthics               // 5.05
    case changeInShellStatus                   // 5.06
    case submissionOfMattersToVote             // 5.07
    case shareholderNominations                // 5.08
    case assetBackedSecurities                 // 6.01
    case regulationFD                          // 7.01
    case otherEvents                           // 8.01
    case financialStatementsAndExhibits        // 9.01
    case unknown(String)

    public var code: String {
        switch self {
        case .materialAgreement: return "1.01"
        case .terminationOfAgreement: return "1.02"
        case .bankruptcy: return "1.03"
        case .minesSafetyReport: return "1.04"
        case .acquisitionOrDisposition: return "2.01"
        case .resultsOfOperations: return "2.02"
        case .directFinancialObligation: return "2.03"
        case .triggeringEvents: return "2.04"
        case .costsFromExitActivities: return "2.05"
        case .materialImpairments: return "2.06"
        case .noticeOfDelisting: return "3.01"
        case .unregisteredSalesOfEquity: return "3.02"
        case .materialModToRightsOfHolders: return "3.03"
        case .changeInCertifyingAccountant: return "4.01"
        case .nonRelianceOnFinancials: return "4.02"
        case .changeInControlOfRegistrant: return "5.01"
        case .departureOfDirectorsOrOfficers: return "5.02"
        case .amendmentsToArticles: return "5.03"
        case .temporarySuspensionOfTrading: return "5.04"
        case .amendmentToCodeOfEthics: return "5.05"
        case .changeInShellStatus: return "5.06"
        case .submissionOfMattersToVote: return "5.07"
        case .shareholderNominations: return "5.08"
        case .assetBackedSecurities: return "6.01"
        case .regulationFD: return "7.01"
        case .otherEvents: return "8.01"
        case .financialStatementsAndExhibits: return "9.01"
        case .unknown(let code): return code
        }
    }

    public var description: String {
        switch self {
        case .materialAgreement: return "Entry into a Material Definitive Agreement"
        case .terminationOfAgreement: return "Termination of a Material Definitive Agreement"
        case .bankruptcy: return "Bankruptcy or Receivership"
        case .minesSafetyReport: return "Mine Safety Reporting"
        case .acquisitionOrDisposition: return "Completion of Acquisition or Disposition of Assets"
        case .resultsOfOperations: return "Results of Operations and Financial Condition"
        case .directFinancialObligation: return "Creation of a Direct Financial Obligation"
        case .triggeringEvents: return "Triggering Events That Accelerate or Increase an Obligation"
        case .costsFromExitActivities: return "Costs Associated with Exit or Disposal Activities"
        case .materialImpairments: return "Material Impairments"
        case .noticeOfDelisting: return "Notice of Delisting or Failure to Satisfy Listing Rule"
        case .unregisteredSalesOfEquity: return "Unregistered Sales of Equity Securities"
        case .materialModToRightsOfHolders: return "Material Modification to Rights of Security Holders"
        case .changeInCertifyingAccountant: return "Changes in Registrant's Certifying Accountant"
        case .nonRelianceOnFinancials: return "Non-Reliance on Previously Issued Financial Statements"
        case .changeInControlOfRegistrant: return "Changes in Control of Registrant"
        case .departureOfDirectorsOrOfficers: return "Departure/Election of Directors or Principal Officers"
        case .amendmentsToArticles: return "Amendments to Articles of Incorporation or Bylaws"
        case .temporarySuspensionOfTrading: return "Temporary Suspension of Trading Under Employee Benefit Plans"
        case .amendmentToCodeOfEthics: return "Amendment to Code of Ethics"
        case .changeInShellStatus: return "Change in Shell Company Status"
        case .submissionOfMattersToVote: return "Submission of Matters to a Vote of Security Holders"
        case .shareholderNominations: return "Shareholder Director Nominations"
        case .assetBackedSecurities: return "ABS Informational and Computational Material"
        case .regulationFD: return "Regulation FD Disclosure"
        case .otherEvents: return "Other Events"
        case .financialStatementsAndExhibits: return "Financial Statements and Exhibits"
        case .unknown(let code): return "Unknown event (\(code))"
        }
    }

    public static func from(code: String) -> EightKItem {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "1.01": return .materialAgreement
        case "1.02": return .terminationOfAgreement
        case "1.03": return .bankruptcy
        case "1.04": return .minesSafetyReport
        case "2.01": return .acquisitionOrDisposition
        case "2.02": return .resultsOfOperations
        case "2.03": return .directFinancialObligation
        case "2.04": return .triggeringEvents
        case "2.05": return .costsFromExitActivities
        case "2.06": return .materialImpairments
        case "3.01": return .noticeOfDelisting
        case "3.02": return .unregisteredSalesOfEquity
        case "3.03": return .materialModToRightsOfHolders
        case "4.01": return .changeInCertifyingAccountant
        case "4.02": return .nonRelianceOnFinancials
        case "5.01": return .changeInControlOfRegistrant
        case "5.02": return .departureOfDirectorsOrOfficers
        case "5.03": return .amendmentsToArticles
        case "5.04": return .temporarySuspensionOfTrading
        case "5.05": return .amendmentToCodeOfEthics
        case "5.06": return .changeInShellStatus
        case "5.07": return .submissionOfMattersToVote
        case "5.08": return .shareholderNominations
        case "6.01": return .assetBackedSecurities
        case "7.01": return .regulationFD
        case "8.01": return .otherEvents
        case "9.01": return .financialStatementsAndExhibits
        default: return .unknown(trimmed)
        }
    }
}

// MARK: - 8-K Service

extension EdgarClient {

    /// Get recent 8-K filings with parsed event items.
    public func getEightKFilings(cik: Int, limit: Int = 20) async throws -> [EightKFiling] {
        let url = try Self.submissionsURL(cik: cik)
        let data = try await getData(from: url)
        let response = try JSONDecoder().decode(SubmissionsResponse.self, from: data)
        let recent = response.filings.recent
        let items = recent.items ?? []
        var results: [EightKFiling] = []

        let count = min(
            recent.accessionNumber.count,
            recent.form.count
        )

        for i in 0..<count {
            guard recent.form[i] == "8-K" || recent.form[i] == "8-K/A" else { continue }

            let filing = Filing(
                accessionNumber: recent.accessionNumber[i],
                filingDate: recent.filingDate[i],
                reportDate: recent.reportDate[i],
                form: recent.form[i],
                primaryDocument: recent.primaryDocument[i],
                primaryDocDescription: recent.primaryDocDescription[i]
            )

            let itemCodes: [EightKItem]
            if i < items.count {
                itemCodes = items[i]
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { EightKItem.from(code: $0) }
            } else {
                itemCodes = []
            }

            results.append(EightKFiling(filing: filing, items: itemCodes))
            if results.count >= limit { break }
        }

        return results
    }
}
