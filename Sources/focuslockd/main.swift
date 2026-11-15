import Darwin
import FocusLockCore
import Foundation

let arguments = CommandLine.arguments

// Used by the installer so the plists exist in exactly one place.
if let i = arguments.firstIndex(of: "--print-plist"), i + 1 < arguments.count {
    guard let service = Service.allCases.first(where: { $0.label == arguments[i + 1] }) else {
        fputs("unknown service \(arguments[i + 1])\n", stderr)
        exit(2)
    }
    print(service.plist, terminator: "")
    exit(0)
}

guard getuid() == 0 else {
    fputs("focuslockd must run as root (it is started by launchd)\n", stderr)
    exit(1)
}

let runner: Runner = arguments.contains("--guard") ? GuardRunner() : MainRunner()
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(100))
timer.setEventHandler { runner.tick() }
timer.resume()
dispatchMain()
