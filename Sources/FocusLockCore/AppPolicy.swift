import Foundation

/// Decides which running apps a session closes. Used by the daemon (which enforces)
/// and by the app (which asks the same apps to quit politely first).
public enum AppPolicy {
    public static let ownAppID = "com.focuslock.app"

    /// Closed during every session: System Settings can switch background services off.
    public static let alwaysClosed: Set<String> = ["com.apple.systempreferences"]

    /// "/Applications/Discord.app/Contents/Frameworks/Discord Helper.app/Contents/MacOS/x"
    /// -> "/Applications/Discord.app". Helpers count as their outermost app.
    public static func outerBundle(ofExecutable path: String) -> String? {
        guard let r = path.range(of: ".app/") else { return nil }
        return String(path[..<r.lowerBound]) + ".app"
    }

    private static let systemAppDirs = [
        "/System/Applications/",
        "/System/Volumes/Preboot/Cryptexes/App/System/Applications/",
    ]
    private static let systemInternals = ["/System/", "/Library/", "/usr/", "/bin/", "/sbin/", "/private/var/db/"]

    /// User-facing apps are in scope. Finder, Dock and other system internals never are.
    public static func inScope(bundlePath: String) -> Bool {
        if systemAppDirs.contains(where: bundlePath.hasPrefix) { return true }
        if systemInternals.contains(where: bundlePath.hasPrefix) { return false }
        return true
    }

    /// `isAgent`: menu bar or background app without a Dock icon. Those survive allow-only mode,
    /// otherwise every helper tool on the Mac would have to be put on the list.
    public static func shouldClose(bundlePath: String, bundleID: String?, isAgent: Bool, rules: Rules) -> Bool {
        guard inScope(bundlePath: bundlePath) else { return false }
        guard let id = bundleID else { return rules.mode == .allowOnly && !isAgent }
        if id == ownAppID { return false }
        if alwaysClosed.contains(id) { return true }
        switch rules.mode {
        case .block: return rules.apps.contains(id)
        case .allowOnly: return !isAgent && !rules.apps.contains(id)
        }
    }
}
