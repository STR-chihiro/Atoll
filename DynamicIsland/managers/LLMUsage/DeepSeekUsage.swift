/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import Foundation
import Defaults
import Security

struct DeepSeekAccount: Codable, Defaults.Serializable, Equatable, Identifiable {
    static let defaultBaseURL = "https://api.deepseek.com"

    let id: UUID
    var name: String
    var baseURL: String

    init(id: UUID = UUID(), name: String, baseURL: String = defaultBaseURL) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
    }
}

struct DeepSeekBalance: Equatable, Identifiable {
    let id: String
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String
}

struct DeepSeekAccountSnapshot: Equatable, Identifiable {
    let id: UUID
    let name: String
    let balances: [DeepSeekBalance]
    let errorMessage: String?

    var isSuccessful: Bool { errorMessage == nil }
}

protocol DeepSeekAccountProviding {
    func accounts() -> [DeepSeekAccount]
    func apiKey(for account: DeepSeekAccount) -> String?
}

enum DeepSeekKeychain {
    private static let service = "com.Ebullioscopic.Atoll.deepseek"

    static func read(accountID: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ apiKey: String, accountID: UUID) throws {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecSuccess || updateStatus == errSecItemNotFound else {
            throw DeepSeekKeychainError(status: updateStatus)
        }
        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw DeepSeekKeychainError(status: addStatus) }
        }
    }

    static func delete(accountID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeepSeekKeychainError(status: status)
        }
    }
}

struct DeepSeekKeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        String(format: String(localized: "Unable to store the DeepSeek API key (Keychain status %d)."), Int(status))
    }
}

struct DeepSeekAccountStore: DeepSeekAccountProviding {
    func accounts() -> [DeepSeekAccount] { Defaults[.deepSeekAccounts] }

    func apiKey(for account: DeepSeekAccount) -> String? {
        DeepSeekKeychain.read(accountID: account.id)
    }

    static func upsert(_ account: DeepSeekAccount, apiKey: String) throws {
        var account = account
        account.name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        account.baseURL = account.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.name.isEmpty else {
            throw DeepSeekStoreError.invalidName
        }
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = Defaults[.deepSeekAccounts].contains { $0.id == account.id }
        let storedKey = DeepSeekKeychain.read(accountID: account.id)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty && (!existing || storedKey?.isEmpty != false) {
            throw DeepSeekStoreError.missingAPIKey
        }
        guard DeepSeekClient.normalizedBaseURL(account.baseURL) != nil else {
            throw DeepSeekStoreError.invalidBaseURL
        }
        if !trimmedKey.isEmpty {
            try DeepSeekKeychain.save(trimmedKey, accountID: account.id)
        }
        var accounts = Defaults[.deepSeekAccounts]
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        Defaults[.deepSeekAccounts] = accounts
    }

    static func delete(_ account: DeepSeekAccount) throws {
        try DeepSeekKeychain.delete(accountID: account.id)
        var accounts = Defaults[.deepSeekAccounts]
        accounts.removeAll { $0.id == account.id }
        Defaults[.deepSeekAccounts] = accounts
    }
}

enum DeepSeekStoreError: LocalizedError {
    case invalidName
    case missingAPIKey
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return String(localized: "Enter a name for this DeepSeek account.")
        case .missingAPIKey:
            return String(localized: "Enter an API key for this DeepSeek account.")
        case .invalidBaseURL:
            return String(localized: "Enter a valid DeepSeek URL, including http:// or https://.")
        }
    }
}

struct DeepSeekClient {
    typealias RequestHandler = (URLRequest) async throws -> (Data, URLResponse)

    private let requestHandler: RequestHandler

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.requestHandler = { request in try await session.data(for: request) }
    }

    init(requestHandler: @escaping RequestHandler) {
        self.requestHandler = requestHandler
    }

    static func normalizedBaseURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        components?.path = path.isEmpty ? "" : "/\(path)"
        return components?.url
    }

    static func balanceURL(forBaseURL baseURL: URL) -> URL {
        baseURL.appendingPathComponent("user").appendingPathComponent("balance")
    }

    func fetchAccount(_ account: DeepSeekAccount, apiKey: String) async throws -> DeepSeekAccountSnapshot {
        guard let baseURL = Self.normalizedBaseURL(account.baseURL) else {
            throw DeepSeekClientError.invalidBaseURL
        }
        let data = try await request(url: Self.balanceURL(forBaseURL: baseURL), apiKey: apiKey)
        let response = try decode(DeepSeekBalanceResponse.self, from: data)
        let balances = response.balanceInfos.enumerated().map { index, info in
            DeepSeekBalance(
                id: "\(index)-\(info.currency)",
                currency: info.currency,
                totalBalance: info.totalBalance,
                grantedBalance: info.grantedBalance,
                toppedUpBalance: info.toppedUpBalance
            )
        }

        let errorMessage: String?
        if !response.isAvailable {
            errorMessage = DeepSeekClientError.unavailable.errorDescription
        } else if balances.isEmpty {
            errorMessage = DeepSeekClientError.noBalance.errorDescription
        } else {
            errorMessage = nil
        }

        return DeepSeekAccountSnapshot(
            id: account.id,
            name: account.name,
            balances: balances,
            errorMessage: errorMessage
        )
    }

    private func request(url: URL, apiKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await requestHandler(request)
        guard let http = response as? HTTPURLResponse else {
            throw DeepSeekClientError.httpFailure(statusCode: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DeepSeekClientError.httpFailure(statusCode: http.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw DeepSeekClientError.invalidResponse }
    }
}

private struct DeepSeekBalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [DeepSeekBalancePayload]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

private struct DeepSeekBalancePayload: Decodable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currency = try container.decode(String.self, forKey: .currency)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currency.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .currency,
                in: container,
                debugDescription: "Expected a currency code"
            )
        }
        self.currency = currency
        totalBalance = try Self.decodeAmount(forKey: .totalBalance, from: container)
        grantedBalance = try Self.decodeAmount(forKey: .grantedBalance, from: container)
        toppedUpBalance = try Self.decodeAmount(forKey: .toppedUpBalance, from: container)
    }

    private static func decodeAmount(
        forKey key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> String {
        if let value = try? container.decode(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return format(value)
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return format(Double(value))
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: container.codingPath + [key],
                debugDescription: "Expected a balance string or number"
            )
        )
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

enum DeepSeekClientError: LocalizedError {
    case invalidBaseURL
    case invalidURL
    case httpFailure(statusCode: Int?)
    case invalidResponse
    case unavailable
    case noBalance

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return String(localized: "Invalid DeepSeek URL")
        case .invalidURL:
            return String(localized: "Invalid DeepSeek request URL")
        case .httpFailure(let statusCode?):
            return String(format: String(localized: "DeepSeek request failed (%d)"), statusCode)
        case .httpFailure(nil):
            return String(localized: "DeepSeek request failed")
        case .invalidResponse:
            return String(localized: "DeepSeek returned an invalid response")
        case .unavailable:
            return String(localized: "DeepSeek account is unavailable")
        case .noBalance:
            return String(localized: "DeepSeek returned no balance")
        }
    }
}

struct DeepSeekUsageProvider: UsageProvider {
    let id: ProviderID = .deepseek
    let accountSource: DeepSeekAccountProviding
    let client: DeepSeekClient

    init(accountSource: DeepSeekAccountProviding = DeepSeekAccountStore(), client: DeepSeekClient = DeepSeekClient()) {
        self.accountSource = accountSource
        self.client = client
    }

    func fetchSnapshot(now: Date) async throws -> UsageSnapshot {
        let accounts = accountSource.accounts()
        guard !accounts.isEmpty else {
            throw UsageError.notConfigured(String(localized: "No DeepSeek accounts configured"))
        }

        let snapshots = await withTaskGroup(of: DeepSeekAccountSnapshot.self, returning: [DeepSeekAccountSnapshot].self) { group in
            for account in accounts {
                group.addTask {
                    guard let apiKey = accountSource.apiKey(for: account)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                          !apiKey.isEmpty else {
                        return DeepSeekAccountSnapshot(
                            id: account.id,
                            name: account.name,
                            balances: [],
                            errorMessage: String(localized: "DeepSeek API key not configured")
                        )
                    }
                    do {
                        return try await client.fetchAccount(account, apiKey: apiKey)
                    } catch {
                        return DeepSeekAccountSnapshot(
                            id: account.id,
                            name: account.name,
                            balances: [],
                            errorMessage: error.localizedDescription
                        )
                    }
                }
            }
            var result: [DeepSeekAccountSnapshot] = []
            for await snapshot in group { result.append(snapshot) }
            return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        var snapshot = UsageSnapshot()
        snapshot.deepSeekAccounts = snapshots
        snapshot.lastUpdated = now
        return snapshot
    }
}
