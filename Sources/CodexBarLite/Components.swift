import AppKit

// MARK: - Symbol helpers

enum Symbols {
    static func image(_ name: String, pointSize: CGFloat, weight: NSFont.Weight = .regular) -> NSImage? {
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        return symbol?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight))
    }

    static func view(_ name: String, pointSize: CGFloat, weight: NSFont.Weight = .regular, tint: NSColor) -> NSImageView {
        let imageView = NSImageView(image: image(name, pointSize: pointSize, weight: weight) ?? NSImage())
        imageView.contentTintColor = tint
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        return imageView
    }
}

/// Spacer that always stretches first inside a stack view.
func flexibleSpacer() -> NSView {
    let view = NSView()
    view.setContentHuggingPriority(.init(1), for: .horizontal)
    view.setContentHuggingPriority(.init(1), for: .vertical)
    view.setContentCompressionResistancePriority(.init(1), for: .horizontal)
    view.setContentCompressionResistancePriority(.init(1), for: .vertical)
    return view
}

// MARK: - Progress ring

/// Circular usage ring: faint track with a round-capped accent arc, drawn from 12 o'clock clockwise.
final class ProgressRingView: NSView {
    var progress: Double = 0 {
        didSet { needsDisplay = true; updateAccessibilityValue() }
    }

    var ringColor: NSColor = AppBranding.accentColor {
        didSet { needsDisplay = true }
    }

    var lineWidth: CGFloat = 11 {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        updateAccessibilityValue()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return }

        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor.quaternaryLabelColor.setStroke()
        track.stroke()

        let clamped = min(1, max(0, progress))
        guard clamped > 0 else { return }

        let arc = NSBezierPath()
        if clamped >= 1 {
            arc.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        } else {
            arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * clamped, clockwise: true)
        }
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        ringColor.setStroke()
        arc.stroke()
    }

    private func updateAccessibilityValue() {
        setAccessibilityRole(.progressIndicator)
        setAccessibilityValue(NSNumber(value: Int(progress * 100)))
    }
}

// MARK: - Rounded group container

/// Softly rounded tonal container for grouped rows. Depth comes from tonal
/// separation (drawn per-appearance), not shadows or borders.
final class RoundedGroupView: NSView {
    let stack = NSStackView()

    var cornerRadius: CGFloat = 10

    init(insets: NSEdgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12), spacing: CGFloat = 0) {
        super.init(frame: .zero)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.edgeInsets = insets
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func addRow(_ row: NSView) {
        stack.addArrangedSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: stack.edgeInsets.left),
            row.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -stack.edgeInsets.right)
        ])
    }

    func addDivider(leadingInset: CGFloat = 0) {
        let container = NSView()
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(divider)

        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leadingInset),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        addRow(container)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
    }
}

// MARK: - Pill label

/// Small tonal chip (e.g. the plan badge in the popover header).
final class PillLabel: NSView {
    private let label = NSTextField(labelWithString: "")

    var text: String {
        get { label.stringValue }
        set { label.stringValue = newValue; invalidateIntrinsicContentSize() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        path.fill()
    }
}

// MARK: - Thin progress bar

/// Compact linear bar used for the secondary window, subordinate to the hero ring.
final class ThinBarView: NSView {
    var progress = 0 {
        didSet { needsDisplay = true }
    }

    var barColor: NSColor = AppBranding.accentColor {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = bounds.insetBy(dx: 0, dy: 0.5)
        let track = NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2)
        NSColor.quaternaryLabelColor.setFill()
        track.fill()

        let width = bounds.width * CGFloat(min(100, max(0, progress))) / 100
        guard width > 0 else { return }

        let fillRect = NSRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2)
        barColor.setFill()
        fill.fill()
    }
}
