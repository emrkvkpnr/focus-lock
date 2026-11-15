import Darwin
import Foundation

func log(_ message: String) {
    fputs("\(Date()) \(message)\n", stderr)
}

enum System {
    /// Seconds on a clock that keeps running during sleep and ignores date changes.
    static func monotonic() -> Double {
        Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000
    }

    static let bootID: String = {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buf, &size, nil, 0) == 0 else { return "unknown" }
        return String(cString: buf)
    }()

    @discardableResult
    static func run(_ tool: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            log("could not run \(tool): \(error)")
            return -1
        }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
