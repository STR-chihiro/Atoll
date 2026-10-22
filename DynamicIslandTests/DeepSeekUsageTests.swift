/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import Foundation
import XCTest
@testable import Atoll

final class DeepSeekUsageTests: XCTestCase {
    func testNormalizesBaseURLAndBuildsBalanceEndpoint() {
        XCTAssertEqual(
            DeepSeekClient.normalizedBaseURL(" https://api.deepseek.com/ ")?.absoluteString,
            "https://api.deepseek.com"
        )
        XCTAssertEqual(
            DeepSeekClient.balanceURL(forBaseURL: URL(string: "https://api.deepseek.com")!).absoluteString,
            "https://api.deepseek.com/user/balance"
        )
        XCTAssertEqual(
            DeepSeekClient.normalizedBaseURL("https://example.com/proxy/")
                .map(DeepSeekClient.balanceURL(forBaseURL:))?.absoluteString,
            "https://example.com/proxy/user/balance"
        )
        XCTAssertNil(DeepSeekClient.normalizedBaseURL("https://api.deepseek.com?token=secret"))
        XCTAssertNil(DeepSeekClient.normalizedBaseURL("api.deepseek.com"))
        XCTAssertEqual(DeepSeekAccount.defaultBaseURL, "https://api.deepseek.com")
    }

    func testFetchBalanceUsesBearerAuthAndKeepsStringAmounts() async throws {
        let recorder = DeepSeekRequestRecorder()
        let client = DeepSeekClient { request in
            recorder.append(request)
            let body = """
            {"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"110.00","granted_balance":"10.00","topped_up_balance":"100.00"}]}
            """
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        let account = DeepSeekAccount(name: "Primary", baseURL: "https://api.deepseek.com/")
        let snapshot = try await client.fetchAccount(account, apiKey: "secret-key")

        XCTAssertEqual(snapshot.balances.count, 1)
        XCTAssertEqual(snapshot.balances[0].currency, "CNY")
        XCTAssertEqual(snapshot.balances[0].totalBalance, "110.00")
        XCTAssertEqual(snapshot.balances[0].grantedBalance, "10.00")
        XCTAssertEqual(snapshot.balances[0].toppedUpBalance, "100.00")
        XCTAssertNil(snapshot.errorMessage)
        XCTAssertEqual(recorder.requests.count, 1)
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/user/balance")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertFalse(request.url?.absoluteString.contains("secret-key") == true)
    }

    func testNumericBalancesAndUnavailableAccountStayVisible() async throws {
        let client = DeepSeekClient { request in
            let body = """
            {"is_available":false,"balance_infos":[{"currency":"USD","total_balance":1.5,"granted_balance":0,"topped_up_balance":"1.50"}]}
            """
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        let snapshot = try await client.fetchAccount(
            DeepSeekAccount(name: "Unavailable", baseURL: "https://api.deepseek.com"),
            apiKey: "key"
        )

        XCTAssertEqual(snapshot.balances[0].totalBalance, "1.50")
        XCTAssertEqual(snapshot.balances[0].grantedBalance, "0.00")
        XCTAssertEqual(snapshot.balances[0].toppedUpBalance, "1.50")
        XCTAssertEqual(snapshot.errorMessage, String(localized: "DeepSeek account is unavailable"))
    }

    func testHTTPFailureDoesNotExposeTheAPIKey() async throws {
        let client = DeepSeekClient { request in
            (
                Data(),
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            )
        }
        let account = DeepSeekAccount(name: "Rejected", baseURL: "https://api.deepseek.com")
        let source = DeepSeekTestAccountSource(accounts: [account], keys: [account.id: "secret-key"])
        let snapshot = try await DeepSeekUsageProvider(accountSource: source, client: client)
            .fetchSnapshot(now: Date(timeIntervalSince1970: 1_700_000_000))

        let error = try XCTUnwrap(snapshot.deepSeekAccounts[0].errorMessage)
        XCTAssertEqual(error, String(format: String(localized: "DeepSeek request failed (%d)"), 401))
        XCTAssertTrue(snapshot.deepSeekAccounts[0].balances.isEmpty)
        XCTAssertFalse(error.contains("secret-key"))
    }

    func testProviderKeepsAccountFailuresIsolated() async throws {
        let first = DeepSeekAccount(name: "10 Production", baseURL: "https://first.example")
        let second = DeepSeekAccount(name: "20 Staging", baseURL: "https://second.example")
        let source = DeepSeekTestAccountSource(
            accounts: [second, first],
            keys: [first.id: "first-key", second.id: "second-key"]
        )
        let client = DeepSeekClient { request in
            if request.url?.host == "second.example" {
                throw DeepSeekClientError.invalidResponse
            }
            let body = """
            {"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"5.00","granted_balance":"1.00","topped_up_balance":"4.00"}]}
            """
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        let snapshot = try await DeepSeekUsageProvider(accountSource: source, client: client)
            .fetchSnapshot(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(snapshot.deepSeekAccounts.map(\.name), ["10 Production", "20 Staging"])
        XCTAssertEqual(snapshot.deepSeekAccounts[0].balances[0].totalBalance, "5.00")
        XCTAssertNil(snapshot.deepSeekAccounts[0].errorMessage)
        XCTAssertEqual(
            snapshot.deepSeekAccounts[1].errorMessage,
            String(localized: "DeepSeek returned an invalid response")
        )
        XCTAssertTrue(snapshot.newAPIAccounts.isEmpty)
    }

    func testMissingAPIKeyDoesNotReachClient() async throws {
        let account = DeepSeekAccount(name: "Missing", baseURL: "https://api.deepseek.com")
        let source = DeepSeekTestAccountSource(accounts: [account], keys: [:])
        let client = DeepSeekClient { _ in
            XCTFail("A missing API key must not create a request")
            throw DeepSeekClientError.httpFailure(statusCode: nil)
        }

        let snapshot = try await DeepSeekUsageProvider(accountSource: source, client: client)
            .fetchSnapshot(now: Date())
        XCTAssertEqual(
            snapshot.deepSeekAccounts[0].errorMessage,
            String(localized: "DeepSeek API key not configured")
        )
    }
}

private final class DeepSeekRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests: [URLRequest] = []

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    func append(_ request: URLRequest) {
        lock.lock()
        recordedRequests.append(request)
        lock.unlock()
    }
}

private struct DeepSeekTestAccountSource: DeepSeekAccountProviding {
    let configuredAccounts: [DeepSeekAccount]
    let keys: [UUID: String]

    func accounts() -> [DeepSeekAccount] { configuredAccounts }

    func apiKey(for account: DeepSeekAccount) -> String? { keys[account.id] }
}
