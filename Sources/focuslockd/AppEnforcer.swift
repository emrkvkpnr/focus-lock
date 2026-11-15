import Darwin
import FocusLockCore
import Foundation

/// Closes apps the session rules do not permit. Works from the process table, so it needs
/// no login session and catches apps however they were launched.
final class AppEnforcer {
    private struct BundleInfo {
        let id: String?
        let isAgent: Bool
    }

    private var bundleCache: [String: BundleInfo] = [:]
    /// How many ticks in a row a pid was found although it should be gone.
    private var strikes: [pid_t: Int] = [:]

    func enforce(_ rules: Rules) {
        var stillThere: [pid_t: Int] = [:]
        for pid in Self.allPIDs() {
            guard let exe = Self.executablePath(of: pid),
                  let bundle = AppPolicy.outerBundle(ofExecutable: exe) else { continue }
            let info = bundleInfo(bundle)
            guard AppPolicy.shouldClose(bundlePath: bundle, bundleID: info.id, isAgent: info.isAgent, rules: rules)
            else { continue }
            let count = (strikes[pid] ?? 0) + 1
            stillThere[pid] = count
            // First a normal quit signal, then no more patience.
            kill(pid, count >= 3 ? SIGKILL : SIGTERM)
        }
        strikes = stillThere
    }

    func reset() {
        strikes = [:]
        bundleCache = [:]
    }

    private func bundleInfo(_ bundlePath: String) -> BundleInfo {
        if let cached = bundleCache[bundlePath] { return cached }
        let plist = NSDictionary(contentsOfFile: bundlePath + "/Contents/Info.plist")
        let info = BundleInfo(id: plist?["CFBundleIdentifier"] as? String,
                              isAgent: Self.truthy(plist?["LSUIElement"]) || Self.truthy(plist?["LSBackgroundOnly"]))
        bundleCache[bundlePath] = info
        return info
    }

    private static func truthy(_ value: Any?) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String { return ["1", "yes", "true"].contains(s.lowercased()) }
        return false
    }

    private static func allPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 128)
        let got = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard got > 0 else { return [] }
        return pids.prefix(Int(got)).filter { $0 > 1 }
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return nil }
        return String(cString: buf)
    }
}
