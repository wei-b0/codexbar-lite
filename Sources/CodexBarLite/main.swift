import AppKit
import Foundation

struct CodexAuth: Decodable {
    let tokens: Tokens?

    struct Tokens: Decodable {
        let accessToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }
}

struct CodexUsage: Codable {
    let planType: String
    let rateLimit: RateLimit
    let rateLimitResetCredits: ResetCredits?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case rateLimitResetCredits = "rate_limit_reset_credits"
    }
}

struct RateLimit: Codable {
    let primaryWindow: UsageWindow
    let secondaryWindow: UsageWindow

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

struct UsageWindow: Codable {
    let usedPercent: Int
    let resetAfterSeconds: Int
    let resetAt: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
}

struct ResetCredits: Codable {
    let availableCount: Int

    enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
    }
}

final class CodexBarLiteApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?

    private let usageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem.button?.title = "CX --/--"
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        Task {
            do {
                let token = try readAccessToken()
                let usage = try await fetchUsage(accessToken: token)

                await MainActor.run {
                    self.renderUsage(usage, warning: nil)
                    try? self.writeCache(usage)
                }
            } catch CodexError.notLoggedIn {
                await MainActor.run {
                    self.statusItem.button?.title = "CX Login"
                    self.renderLoginMenu()
                }
            } catch {
                await MainActor.run {
                    if let cached = try? self.readCache() {
                        self.renderUsage(cached, warning: error.localizedDescription)
                        self.statusItem.button?.title += " ⚠"
                    } else {
                        self.statusItem.button?.title = "CX Error"
                        self.renderErrorMenu(error)
                    }
                }
            }
        }
    }

    private func readAccessToken() throws -> String {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")

        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexError.notLoggedIn
        }

        let data = try Data(contentsOf: authURL)
        let auth = try JSONDecoder().decode(CodexAuth.self, from: data)

        guard let token = auth.tokens?.accessToken, !token.isEmpty else {
            throw CodexError.notLoggedIn
        }

        return token
    }

    private func fetchUsage(accessToken: String) async throws -> CodexUsage {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://chatgpt.com/codex", forHTTPHeaderField: "Referer")
        request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        let body = String(data: data, encoding: .utf8) ?? ""

        if body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<html") {
            throw CodexError.cloudflareChallenge
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw CodexError.httpError(http.statusCode)
        }

        return try JSONDecoder().decode(CodexUsage.self, from: data)
    }

    private func renderUsage(_ usage: CodexUsage, warning: String?) {
        let primary = usage.rateLimit.primaryWindow
        let secondary = usage.rateLimit.secondaryWindow

        self.statusItem.button?.title = "CX \(primary.usedPercent)%/\(secondary.usedPercent)% ⚠"

        let menu = NSMenu()

        menu.addItem(withTitle: "Codex \(usage.planType.uppercased())", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "5h: \(primary.usedPercent)% used, \(100 - primary.usedPercent)% left", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Resets in \(formatDuration(primary.resetAfterSeconds))", action: nil, keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "Week: \(secondary.usedPercent)% used, \(100 - secondary.usedPercent)% left", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Resets in \(formatDuration(secondary.resetAfterSeconds))", action: nil, keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let credits = usage.rateLimitResetCredits?.availableCount ?? 0
        menu.addItem(withTitle: "Reset credits: \(credits)", action: nil, keyEquivalent: "")

        if let warning {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "⚠ \(warning)", action: nil, keyEquivalent: "")
        }

        menu.addItem(NSMenuItem.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshMenuAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let login = NSMenuItem(title: "Run codex login", action: #selector(runCodexLogin), keyEquivalent: "l")
        login.target = self
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func renderLoginMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "Codex login required", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Run `codex login` once.", action: nil, keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let login = NSMenuItem(title: "Run codex login", action: #selector(runCodexLogin), keyEquivalent: "l")
        login.target = self
        menu.addItem(login)

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshMenuAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func renderErrorMenu(_ error: Error) {
        let menu = NSMenu()

        menu.addItem(withTitle: "CodexBarLite error", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: error.localizedDescription, action: nil, keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshMenuAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func refreshMenuAction() {
        refresh()
    }

    @objc private func runCodexLogin() {
        let script = """
        tell application "Terminal"
            activate
            do script "codex login"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        try? process.run()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func cacheURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexBarLite/usage.json")
    }

    private func writeCache(_ usage: CodexUsage) throws {
        let url = cacheURL()

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(usage)
        try data.write(to: url)
    }

    private func readCache() throws -> CodexUsage {
        let data = try Data(contentsOf: cacheURL())
        return try JSONDecoder().decode(CodexUsage.self, from: data)
    }
}

enum CodexError: LocalizedError {
    case notLoggedIn
    case invalidResponse
    case cloudflareChallenge
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Not logged in."
        case .invalidResponse:
            return "Invalid response."
        case .cloudflareChallenge:
            return "Cloudflare challenge. Showing cached usage."
        case .httpError(let status):
            return "Request failed with status \(status)."
        }
    }
}

let app = NSApplication.shared
let delegate = CodexBarLiteApp()
app.delegate = delegate
app.run()