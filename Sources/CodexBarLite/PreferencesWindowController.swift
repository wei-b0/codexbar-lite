import AppKit
import ServiceManagement

final class PreferencesWindowController: NSWindowController {
    private let settings: SettingsStore
    private let onCheckForUpdates: () -> Void
    private let refreshPopup = NSPopUpButton()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch CodexBar Lite at login", target: nil, action: nil)
    private let displayPopup = NSPopUpButton()
    private let checkForUpdatesButton = NSButton(checkboxWithTitle: "Automatically check for updates", target: nil, action: nil)
    private let notifyAt80Button = NSButton(checkboxWithTitle: "Notify at 80% usage", target: nil, action: nil)
    private let notifyAt90Button = NSButton(checkboxWithTitle: "Notify at 90% usage", target: nil, action: nil)
    private let notifyExhaustedButton = NSButton(checkboxWithTitle: "Notify when exhausted", target: nil, action: nil)
    private let notifyResetButton = NSButton(checkboxWithTitle: "Notify when credits reset", target: nil, action: nil)

    init(settings: SettingsStore, onCheckForUpdates: @escaping () -> Void) {
        self.settings = settings
        self.onCheckForUpdates = onCheckForUpdates

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CodexBar Lite Preferences"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        buildContent()
        syncControls()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        syncControls()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])

        stack.addArrangedSubview(sectionTitle("General"))

        refreshPopup.addItems(withTitles: ["1 minute", "5 minutes", "15 minutes", "30 minutes"])
        refreshPopup.target = self
        refreshPopup.action = #selector(refreshIntervalChanged)
        refreshPopup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        stack.addArrangedSubview(row(label: "Refresh interval", control: refreshPopup))

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)
        stack.addArrangedSubview(launchAtLoginButton)

        displayPopup.addItems(withTitles: ["Percentage used", "Percentage remaining"])
        displayPopup.target = self
        displayPopup.action = #selector(displayModeChanged)
        displayPopup.widthAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(row(label: "Menu bar display", control: displayPopup))

        checkForUpdatesButton.target = self
        checkForUpdatesButton.action = #selector(checkForUpdatesChanged)
        stack.addArrangedSubview(checkForUpdatesButton)

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionTitle("Notifications"))

        for button in [notifyAt80Button, notifyAt90Button, notifyExhaustedButton, notifyResetButton] {
            button.target = self
            button.action = #selector(notificationPreferenceChanged)
            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionTitle("About"))

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let aboutLabel = NSTextField(
            labelWithString: """
            CodexBar Lite \(version) — Native Codex usage from your existing CLI session.
            No browser cookies, Keychain access, telemetry, or analytics.
            Independent utility; not affiliated with OpenAI.
            """
        )
        aboutLabel.textColor = .secondaryLabelColor
        aboutLabel.maximumNumberOfLines = 3
        stack.addArrangedSubview(aboutLabel)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let aboutButton = NSButton(title: "View on GitHub", target: self, action: #selector(openGitHub))
        let updateButton = NSButton(title: "Check for Updates…", target: self, action: #selector(checkForUpdates))
        buttons.addArrangedSubview(aboutButton)
        buttons.addArrangedSubview(updateButton)
        stack.addArrangedSubview(buttons)
    }

    private func syncControls() {
        let intervals: [TimeInterval] = [60, 300, 900, 1800]
        let selectedInterval = intervals.enumerated().min(by: {
            abs($0.element - settings.refreshInterval) < abs($1.element - settings.refreshInterval)
        })?.offset ?? 1
        refreshPopup.selectItem(at: selectedInterval)
        launchAtLoginButton.state = SMAppService.mainApp.status == .enabled ? .on : .off
        displayPopup.selectItem(at: settings.displayMode == .used ? 0 : 1)
        checkForUpdatesButton.state = settings.checkForUpdates ? .on : .off
        notifyAt80Button.state = settings.notifyAt80 ? .on : .off
        notifyAt90Button.state = settings.notifyAt90 ? .on : .off
        notifyExhaustedButton.state = settings.notifyWhenExhausted ? .on : .off
        notifyResetButton.state = settings.notifyWhenReset ? .on : .off
    }

    private func row(label: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let text = NSTextField(labelWithString: label)
        text.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(text)
        row.addArrangedSubview(control)
        return row
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 412).isActive = true
        return box
    }

    @objc private func refreshIntervalChanged() {
        let intervals: [TimeInterval] = [60, 300, 900, 1800]
        settings.refreshInterval = intervals[max(0, refreshPopup.indexOfSelectedItem)]
    }

    @objc private func launchAtLoginChanged() {
        do {
            try settings.setLaunchAtLogin(launchAtLoginButton.state == .on)
        } catch {
            syncControls()
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn’t update Launch at Login"
            alert.runModal()
        }
    }

    @objc private func displayModeChanged() {
        settings.displayMode = displayPopup.indexOfSelectedItem == 0 ? .used : .remaining
    }

    @objc private func checkForUpdatesChanged() {
        settings.checkForUpdates = checkForUpdatesButton.state == .on
    }

    @objc private func notificationPreferenceChanged() {
        settings.notifyAt80 = notifyAt80Button.state == .on
        settings.notifyAt90 = notifyAt90Button.state == .on
        settings.notifyWhenExhausted = notifyExhaustedButton.state == .on
        settings.notifyWhenReset = notifyResetButton.state == .on
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/wei-b0/codexbar-lite")!)
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }
}
