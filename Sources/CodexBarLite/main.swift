import AppKit
import Foundation
import Sparkle

struct CodexAuth: Decodable {
    let tokens: Tokens?

    struct Tokens: Decodable {
        let accessToken: String?
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
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
    let allowed: Bool?
    let limitReached: Bool?
    let primaryWindow: UsageWindow
    let secondaryWindow: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

struct UsageWindow: Codable {
    let usedPercent: Int
    let limitWindowSeconds: Int?
    let resetAfterSeconds: Int
    let resetAt: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
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
    private let settings = SettingsStore.shared
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/codex/usage")!
    private lazy var notificationManager = NotificationManager(settings: settings)
    private lazy var preferencesController = PreferencesWindowController(settings: settings) { [weak self] in
        self?.checkForUpdates()
    }
    private var updaterController: SPUStandardUpdaterController?
    private var refreshTimer: Timer?
    private var loginPollTimer: Timer?
    private var lastUsage: CodexUsage?
    private var lastUpdatedAt: Date?
    private var lastWarning: String?
    private var loginLaunched = false
    private var authFingerprintBeforeLogin: String?
    private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem.button?.title = "Codex ◔ …"

        settings.applyLaunchAtLoginDefaultIfNeeded()
        configureUpdater()
        configureRefreshTimer()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .codexBarSettingsDidChange,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureUpdater() {
        guard Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil,
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil else {
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
    }

    private func configureRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            do {
                let auth = try readAuth()
                let usage = try await fetchUsage(auth: auth)

                await MainActor.run {
                    let updatedAt = Date()
                    self.loginPollTimer?.invalidate()
                    self.loginPollTimer = nil
                    self.renderUsage(usage, updatedAt: updatedAt, warning: nil)
                    self.notificationManager.requestAuthorizationIfNeeded()
                    self.notificationManager.evaluate(usage)
                    try? self.writeCache(usage)
                    self.isRefreshing = false
                }
            } catch CodexError.notLoggedIn {
                await MainActor.run {
                    self.handleNotLoggedIn()
                    self.isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    if let cached = try? self.readCache() {
                        self.renderUsage(cached.usage, updatedAt: cached.updatedAt, warning: error.localizedDescription)
                    } else {
                        self.renderErrorMenu(error)
                    }
                    self.isRefreshing = false
                }
            }
        }
    }

    private func handleNotLoggedIn() {
        if !loginLaunched {
            authFingerprintBeforeLogin = authFingerprint()
            loginLaunched = true
            renderLoginMenu(signingIn: true)
            launchCodexLogin()
            startLoginPolling()
        } else {
            renderLoginMenu(signingIn: loginPollTimer != nil)
        }
    }

    private func startLoginPolling() {
        loginPollTimer?.invalidate()
        loginPollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let fingerprint = self.authFingerprint()
            guard fingerprint != nil, fingerprint != self.authFingerprintBeforeLogin else { return }
            self.authFingerprintBeforeLogin = fingerprint
            self.refresh()
        }
    }

    private func readAuth() throws -> CodexAuth.Tokens {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")

        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexError.notLoggedIn
        }

        let data = try Data(contentsOf: authURL)
        let auth = try JSONDecoder().decode(CodexAuth.self, from: data)

        guard let tokens = auth.tokens, let accessToken = tokens.accessToken, !accessToken.isEmpty else {
            throw CodexError.notLoggedIn
        }

        return tokens
    }

    private func authFingerprint() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return "\(date.timeIntervalSince1970)-\(size.intValue)"
    }

    private func fetchUsage(auth: CodexAuth.Tokens) async throws -> CodexUsage {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(auth.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex-cli/0.11.0", forHTTPHeaderField: "User-Agent")
        request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
        if let accountID = auth.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let body = String(data: data, encoding: .utf8) ?? ""

        if body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<html") {
            throw CodexError.cloudflareChallenge
        }

        guard let http = response as? HTTPURLResponse else {
            throw CodexError.invalidResponse
        }

        if http.statusCode == 401 {
            throw CodexError.notLoggedIn
        }

        guard (200..<300).contains(http.statusCode) else {
            throw CodexError.httpError(http.statusCode)
        }

        return try JSONDecoder().decode(CodexUsage.self, from: data)
    }

    private func renderUsage(_ usage: CodexUsage, updatedAt: Date, warning: String?) {
        lastUsage = usage
        lastUpdatedAt = updatedAt
        lastWarning = warning
        updateStatusTitle(for: usage)

        let menu = NSMenu()
        let usageItem = NSMenuItem()
        let usageView = UsageMenuView()
        usageView.update(usage: usage, displayMode: settings.displayMode, updatedAt: updatedAt)
        usageItem.view = usageView
        menu.addItem(usageItem)

        let primary = usage.rateLimit.primaryWindow
        let primaryReset = NSMenuItem(
            title: "Primary resets in \(formatDuration(secondsUntilReset(primary)))",
            action: nil,
            keyEquivalent: ""
        )
        primaryReset.isEnabled = false
        menu.addItem(primaryReset)

        if let secondary = usage.rateLimit.secondaryWindow {
            let secondaryReset = NSMenuItem(
                title: "Secondary resets in \(formatDuration(secondsUntilReset(secondary)))",
                action: nil,
                keyEquivalent: ""
            )
            secondaryReset.isEnabled = false
            menu.addItem(secondaryReset)
        }

        if let credits = usage.rateLimitResetCredits?.availableCount {
            let creditsItem = NSMenuItem(title: "Reset credits: \(credits)", action: nil, keyEquivalent: "")
            creditsItem.isEnabled = false
            menu.addItem(creditsItem)
        }

        if let warning {
            menu.addItem(NSMenuItem.separator())
            let warningItem = NSMenuItem(title: "⚠ \(warning)", action: nil, keyEquivalent: "")
            warningItem.isEnabled = false
            menu.addItem(warningItem)
        }

        menu.addItem(NSMenuItem.separator())
        addCommonActions(to: menu, showLogin: false)
        statusItem.menu = menu
    }

    private func renderLoginMenu(signingIn: Bool) {
        statusItem.button?.title = signingIn ? "Codex ◔ Sign In…" : "Codex ◔ Sign In"
        lastUsage = nil
        lastUpdatedAt = nil

        let menu = NSMenu()
        let title = NSMenuItem(title: "Codex Usage", action: nil, keyEquivalent: "")
        title.attributedTitle = NSAttributedString(
            string: "Codex Usage",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        title.isEnabled = false
        menu.addItem(title)

        let status = NSMenuItem(
            title: signingIn ? "Signing in to Codex…" : "Codex login required",
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)

        if signingIn {
            let terminal = NSMenuItem(title: "Finish login in Terminal. Status updates automatically.", action: nil, keyEquivalent: "")
            terminal.isEnabled = false
            menu.addItem(terminal)
        }

        menu.addItem(NSMenuItem.separator())
        addCommonActions(to: menu, showLogin: true)
        statusItem.menu = menu
    }

    private func renderErrorMenu(_ error: Error) {
        statusItem.button?.title = "Codex ◔ Error"

        let menu = NSMenu()
        let title = NSMenuItem(title: "CodexBar Lite", action: nil, keyEquivalent: "")
        title.attributedTitle = NSAttributedString(
            string: "CodexBar Lite",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        title.isEnabled = false
        menu.addItem(title)

        let message = NSMenuItem(title: error.localizedDescription, action: nil, keyEquivalent: "")
        message.isEnabled = false
        menu.addItem(message)

        menu.addItem(NSMenuItem.separator())
        addCommonActions(to: menu, showLogin: false)
        statusItem.menu = menu
    }

    private func addCommonActions(to menu: NSMenu, showLogin: Bool) {
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMenuAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        if showLogin {
            let loginItem = NSMenuItem(title: "Sign In to Codex", action: #selector(runCodexLogin), keyEquivalent: "")
            loginItem.target = self
            menu.addItem(loginItem)
        }

        menu.addItem(NSMenuItem.separator())

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesMenuAction), keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = updaterController != nil
        menu.addItem(updateItem)

        let aboutItem = NSMenuItem(title: "About CodexBar Lite", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit CodexBar Lite", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updateStatusTitle(for usage: CodexUsage) {
        let primary = displayedPercent(usage.rateLimit.primaryWindow)
        statusItem.button?.title = "Codex ◔ \(primary)%"
        if lastWarning != nil {
            statusItem.button?.title += " ⚠"
        }
    }

    private func displayedPercent(_ window: UsageWindow) -> Int {
        settings.displayMode == .used ? window.usedPercent : 100 - window.usedPercent
    }

    @objc private func refreshMenuAction() {
        refresh()
    }

    @objc private func runCodexLogin() {
        authFingerprintBeforeLogin = authFingerprint()
        loginLaunched = true
        renderLoginMenu(signingIn: true)
        launchCodexLogin()
        startLoginPolling()
    }

    private func launchCodexLogin() {
        let script = """
        tell application "Terminal"
            activate
            do script "codex login"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
        } catch {
            renderErrorMenu(CodexError.loginLaunchFailed)
        }
    }

    @objc private func showPreferences() {
        preferencesController.show()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func checkForUpdatesMenuAction() {
        checkForUpdates()
    }

    private func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func settingsDidChange() {
        configureRefreshTimer()
        if let updater = updaterController?.updater,
           updater.automaticallyChecksForUpdates != settings.checkForUpdates {
            updater.automaticallyChecksForUpdates = settings.checkForUpdates
        }
        notificationManager.requestAuthorizationIfNeeded()

        if let usage = lastUsage, let updatedAt = lastUpdatedAt {
            renderUsage(usage, updatedAt: updatedAt, warning: lastWarning)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds <= 0 { return "0m" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func secondsUntilReset(_ window: UsageWindow) -> Int {
        max(0, window.resetAt - Int(Date().timeIntervalSince1970))
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
        try data.write(to: url, options: .atomic)
    }

    private func readCache() throws -> (usage: CodexUsage, updatedAt: Date) {
        let url = cacheURL()
        let data = try Data(contentsOf: url)
        let usage = try JSONDecoder().decode(CodexUsage.self, from: data)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let updatedAt = attributes[.modificationDate] as? Date ?? Date()
        return (usage, updatedAt)
    }
}

enum CodexError: LocalizedError {
    case notLoggedIn
    case invalidResponse
    case cloudflareChallenge
    case httpError(Int)
    case loginLaunchFailed

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
        case .loginLaunchFailed:
            return "Couldn’t open Terminal for codex login."
        }
    }
}

let app = NSApplication.shared
let delegate = CodexBarLiteApp()
app.delegate = delegate
app.run()
