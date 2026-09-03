import Foundation

public enum WindowRole: String, CaseIterable, Sendable {
    case editor
    case browser
    case terminal
}

public enum RoleCatalog: Sendable {
    public static func role(bundleId: String) -> WindowRole? {
        let id = bundleId.lowercased()
        if editors.contains(id) || id.hasPrefix("com.jetbrains.") {
            return .editor
        }
        if browsers.contains(id) {
            return .browser
        }
        if terminals.contains(id) {
            return .terminal
        }
        return nil
    }

    public static func pickFrontmost<T>(
        role: WindowRole,
        from windows: [T],
        bundleId: (T) -> String,
        focused: (T) -> Bool
    ) -> T? {
        let matches = windows.filter { self.role(bundleId: bundleId($0)) == role }
        if let focusedMatch = matches.first(where: focused) {
            return focusedMatch
        }
        return matches.first
    }

    private static let editors: Set<String> = [
        "com.todesktop.230313mzl4w4u92",
        "com.cursor.cursor",
        "com.microsoft.vscode",
        "com.microsoft.vscodeinsiders",
        "com.apple.dt.xcode",
        "dev.zed.zed",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.exafunction.windsurf",
        "com.panic.nova",
        "com.github.atom",
    ]

    private static let browsers: Set<String> = [
        "com.apple.safari",
        "com.apple.safaritechnologypreview",
        "com.google.chrome",
        "com.google.chrome.canary",
        "company.thebrowser.browser",
        "company.thebrowser.dia",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "com.brave.browser",
        "com.microsoft.edgemac",
        "com.operasoftware.opera",
        "com.vivaldi.vivaldi",
        "app.zen-browser.zen",
    ]

    private static let terminals: Set<String> = [
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.warp-stable",
        "dev.warp.warp",
        "org.alacritty",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
    ]
}
