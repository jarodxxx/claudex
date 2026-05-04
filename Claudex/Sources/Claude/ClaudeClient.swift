import Foundation

enum ClaudeClientError: Error {
    case missingSessionKey
    case unauthorized
    case unexpectedStatus(Int)
    case decodingFailed(underlying: Error)
    case invalidResponse(String)
    case noOrganization
}

/// Talks to claude.ai's internal web API.
///
/// Endpoints (reverse-engineered from `eddmann/ClaudeMeter`, MIT):
///   GET https://claude.ai/api/organizations          → [Organization]
///   GET https://claude.ai/api/organizations/{uuid}/usage → UsageRaw
///
/// Auth is the `sessionKey` cookie (sk-ant-…) read from Keychain. The header
/// set below mimics a real browser request; without it Cloudflare returns 403.
struct ClaudeClient {
    let session: URLSession
    let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://claude.ai/api")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func fetchUsage() async throws -> ClaudeUsage {
        let sessionKey: String
        do {
            sessionKey = try ClaudeAuth.currentSessionKey()
        } catch {
            throw ClaudeClientError.missingSessionKey
        }

        let orgUUID = try await resolveOrganizationUUID(sessionKey: sessionKey)
        let raw: UsageRaw = try await get(path: "/organizations/\(orgUUID)/usage", sessionKey: sessionKey)
        return try mapToUsage(raw)
    }

    private func resolveOrganizationUUID(sessionKey: String) async throws -> String {
        if let cached = AppSettings.claudeOrgUUID { return cached }
        let orgs: [ClaudeOrganization] = try await get(path: "/organizations", sessionKey: sessionKey)
        guard let first = orgs.first else { throw ClaudeClientError.noOrganization }
        AppSettings.claudeOrgUUID = first.uuid
        return first.uuid
    }

    private func get<T: Decodable>(path: String, sessionKey: String) async throws -> T {
        // baseURL path is `/api`; we add the leading slash to ensure
        // appendingPathComponent doesn't lose it.
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let cleanPath = path.hasPrefix("/") ? path : "/" + path
        components.path = (components.path) + cleanPath

        guard let url = components.url else {
            throw ClaudeClientError.invalidResponse("could not build URL for \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeClientError.unexpectedStatus(-1)
        }
        if http.statusCode == 401 { throw ClaudeClientError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw ClaudeClientError.unexpectedStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ClaudeClientError.decodingFailed(underlying: error)
        }
    }

    private func mapToUsage(_ raw: UsageRaw) throws -> ClaudeUsage {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ s: String?) -> Date? {
            guard let s else { return nil }
            return formatter.date(from: s) ?? fallbackFormatter.date(from: s)
        }

        // The API may return `resets_at: null` when there's no usage yet for a
        // window. Fall back to a sensible projection so the user still sees
        // their utilization (which is the important number) instead of an
        // ugly error string.
        let sessionReset = parseDate(raw.fiveHour.resetsAt)
            ?? Date().addingTimeInterval(5 * 3600)
        let weeklyReset = parseDate(raw.sevenDay.resetsAt)
            ?? Date().addingTimeInterval(7 * 24 * 3600)

        let sonnet: PeriodUsage? = raw.sevenDaySonnet.map { p in
            let reset = parseDate(p.resetsAt) ?? Date().addingTimeInterval(7 * 24 * 3600)
            return PeriodUsage(resetAt: reset, utilization: p.utilization)
        }

        return ClaudeUsage(
            lastUpdated: Date(),
            sessionUsage: PeriodUsage(resetAt: sessionReset, utilization: raw.fiveHour.utilization),
            sonnetUsage: sonnet,
            weeklyUsage: PeriodUsage(resetAt: weeklyReset, utilization: raw.sevenDay.utilization)
        )
    }
}

struct ClaudeOrganization: Codable, Equatable {
    let id: Int
    let uuid: String
    let name: String
}

private struct UsageRaw: Codable {
    let fiveHour: PeriodRaw
    let sevenDay: PeriodRaw
    let sevenDaySonnet: PeriodRaw?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}

private struct PeriodRaw: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}
