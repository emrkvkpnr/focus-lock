import Foundation

public enum Paths {
    public static let base = "/Library/Application Support/FocusLock"
    public static let session = base + "/session.json"
    public static let status = base + "/status.json"
    /// World-writable spool. The app drops request files here, the daemon picks them up.
    public static let requests = base + "/requests"
    public static let hosts = "/etc/hosts"
    public static let daemonBinary = "/Library/PrivilegedHelperTools/com.focuslock.daemon"
}

public enum Service: String, CaseIterable, Sendable {
    case main = "com.focuslock.daemon"
    case guardian = "com.focuslock.guard"

    public var label: String { rawValue }
    public var plistPath: String { "/Library/LaunchDaemons/\(rawValue).plist" }

    public var arguments: [String] {
        switch self {
        case .main: return [Paths.daemonBinary]
        case .guardian: return [Paths.daemonBinary, "--guard"]
        }
    }

    public var plist: String {
        let args = arguments.map { "        <string>\($0)</string>" }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
        \(args)
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>ThrottleInterval</key>
            <integer>1</integer>
            <key>StandardErrorPath</key>
            <string>/var/log/focuslock.log</string>
        </dict>
        </plist>

        """
    }
}
