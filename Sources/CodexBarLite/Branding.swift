import AppKit

enum AppBranding {
    static let logoImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "CodexBarLiteLogo", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}
