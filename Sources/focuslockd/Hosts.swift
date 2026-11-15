import Darwin
import FocusLockCore
import Foundation

enum Hosts {
    /// Makes /etc/hosts match the wanted block list. Called repeatedly, so manual edits
    /// during a session are undone. An empty list removes everything FocusLock added.
    static func sync(domains: [String]) {
        let current: String
        do {
            current = try String(contentsOfFile: Paths.hosts, encoding: .utf8)
        } catch {
            log("could not read hosts file: \(error)")
            return
        }
        let wanted = HostsFile.apply(current, domains: domains)
        guard wanted != current else { return }
        do {
            try wanted.write(toFile: Paths.hosts, atomically: true, encoding: .utf8)
            chmod(Paths.hosts, 0o644)
        } catch {
            log("could not write hosts file: \(error)")
            return
        }
        System.run("/usr/bin/dscacheutil", ["-flushcache"])
        System.run("/usr/bin/killall", ["-HUP", "mDNSResponder"])
    }
}
