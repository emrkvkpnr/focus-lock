import Foundation

/// Pure text transformation for /etc/hosts. Everything FocusLock adds sits between two markers.
public enum HostsFile {
    public static let begin = "# >>> FocusLock (automatisch verwaltet, nicht bearbeiten)"
    public static let end = "# <<< FocusLock"

    public static func strip(_ text: String) -> String {
        var out: [String] = []
        var inside = false
        for line in text.components(separatedBy: "\n") {
            if line == begin { inside = true; continue }
            if line == end { inside = false; continue }
            if !inside { out.append(line) }
        }
        while let last = out.last, last.isEmpty { out.removeLast() }
        return out.joined(separator: "\n") + "\n"
    }

    public static func apply(_ text: String, domains: [String]) -> String {
        let base = strip(text)
        guard !domains.isEmpty else { return base }
        var lines = [begin]
        for d in domains {
            for host in [d, "www." + d] {
                lines.append("0.0.0.0 \(host)")
                lines.append(":: \(host)")
            }
        }
        lines.append(end)
        return base + lines.joined(separator: "\n") + "\n"
    }
}
