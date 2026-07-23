import AppKit

final class UsageBarView: NSView {
    var progress = 0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = bounds.insetBy(dx: 0, dy: 1)
        let background = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        NSColor.quaternaryLabelColor.setFill()
        background.fill()

        let width = bounds.width * CGFloat(min(100, max(0, progress))) / 100
        guard width > 0 else { return }

        let fillRect = NSRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 4, yRadius: 4)
        let color: NSColor
        if progress >= 90 {
            color = .systemRed
        } else if progress >= 80 {
            color = .systemOrange
        } else {
            color = .controlAccentColor
        }
        color.setFill()
        fill.fill()
    }
}

final class UsageMenuView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Codex Usage")
    private let planLabel = NSTextField(labelWithString: "")
    private let primaryLabel = NSTextField(labelWithString: "Primary")
    private let primaryValue = NSTextField(labelWithString: "")
    private let primaryBar = UsageBarView()
    private let secondaryLabel = NSTextField(labelWithString: "Secondary")
    private let secondaryValue = NSTextField(labelWithString: "")
    private let secondaryBar = UsageBarView()
    private let updatedLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 174))

        titleLabel.font = .boldSystemFont(ofSize: 15)
        planLabel.font = .systemFont(ofSize: 11, weight: .medium)
        planLabel.textColor = .secondaryLabelColor
        planLabel.alignment = .right
        primaryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        secondaryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        primaryValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        secondaryValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        primaryValue.alignment = .right
        secondaryValue.alignment = .right
        updatedLabel.font = .systemFont(ofSize: 11)
        updatedLabel.textColor = .secondaryLabelColor

        for view in [titleLabel, planLabel, primaryLabel, primaryValue, primaryBar, secondaryLabel, secondaryValue, secondaryBar, updatedLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            planLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            planLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            planLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),

            primaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            primaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            primaryValue.trailingAnchor.constraint(equalTo: planLabel.trailingAnchor),
            primaryValue.centerYAnchor.constraint(equalTo: primaryLabel.centerYAnchor),
            primaryBar.leadingAnchor.constraint(equalTo: primaryLabel.leadingAnchor),
            primaryBar.trailingAnchor.constraint(equalTo: primaryValue.trailingAnchor),
            primaryBar.topAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: 6),
            primaryBar.heightAnchor.constraint(equalToConstant: 8),

            secondaryLabel.leadingAnchor.constraint(equalTo: primaryLabel.leadingAnchor),
            secondaryLabel.topAnchor.constraint(equalTo: primaryBar.bottomAnchor, constant: 14),
            secondaryValue.trailingAnchor.constraint(equalTo: primaryValue.trailingAnchor),
            secondaryValue.centerYAnchor.constraint(equalTo: secondaryLabel.centerYAnchor),
            secondaryBar.leadingAnchor.constraint(equalTo: secondaryLabel.leadingAnchor),
            secondaryBar.trailingAnchor.constraint(equalTo: secondaryValue.trailingAnchor),
            secondaryBar.topAnchor.constraint(equalTo: secondaryLabel.bottomAnchor, constant: 6),
            secondaryBar.heightAnchor.constraint(equalToConstant: 8),

            updatedLabel.leadingAnchor.constraint(equalTo: secondaryBar.leadingAnchor),
            updatedLabel.topAnchor.constraint(equalTo: secondaryBar.bottomAnchor, constant: 16)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(usage: CodexUsage, displayMode: UsageDisplayMode, updatedAt: Date) {
        planLabel.stringValue = usage.planType.uppercased()
        updateWindow(
            usage.rateLimit.primaryWindow,
            label: primaryLabel,
            value: primaryValue,
            bar: primaryBar,
            name: "Primary",
            displayMode: displayMode
        )

        if let secondary = usage.rateLimit.secondaryWindow {
            updateWindow(
                secondary,
                label: secondaryLabel,
                value: secondaryValue,
                bar: secondaryBar,
                name: "Secondary",
                displayMode: displayMode
            )
            secondaryBar.isHidden = false
        } else {
            secondaryLabel.stringValue = "Secondary"
            secondaryValue.stringValue = "Unavailable"
            secondaryValue.textColor = .tertiaryLabelColor
            secondaryBar.isHidden = true
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        updatedLabel.stringValue = "Last updated \(formatter.string(from: updatedAt))"
    }

    private func updateWindow(
        _ window: UsageWindow,
        label: NSTextField,
        value: NSTextField,
        bar: UsageBarView,
        name: String,
        displayMode: UsageDisplayMode
    ) {
        label.stringValue = name
        value.stringValue = displayMode == .used ? "\(window.usedPercent)% used" : "\(100 - window.usedPercent)% remaining"
        value.textColor = .labelColor
        bar.progress = window.usedPercent
    }
}
