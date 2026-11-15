import Darwin
import FocusLockCore
import Foundation

enum Launchd {
    /// Puts a service back if it was unloaded, disabled or its plist deleted.
    static func ensureLoaded(_ service: Service) {
        let target = "system/" + service.label
        guard System.run("/bin/launchctl", ["print", target]) != 0 else { return }
        log("\(service.label) is not loaded, restoring it")
        if !FileManager.default.fileExists(atPath: service.plistPath) {
            do {
                try service.plist.write(toFile: service.plistPath, atomically: true, encoding: .utf8)
                chown(service.plistPath, 0, 0)
                chmod(service.plistPath, 0o644)
            } catch {
                log("could not restore \(service.plistPath): \(error)")
            }
        }
        System.run("/bin/launchctl", ["enable", target])
        System.run("/bin/launchctl", ["bootstrap", "system", service.plistPath])
    }
}
