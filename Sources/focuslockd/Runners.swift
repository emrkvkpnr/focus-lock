import FocusLockCore
import Foundation

protocol Runner: AnyObject {
    func tick()
}

/// The service that holds the session and enforces it.
final class MainRunner: Runner {
    private var session: Session?
    private var ticks = 0
    private let enforcer = AppEnforcer()

    init() {
        Store.prepare()
        session = Store.loadSession()
        if session == nil { Hosts.sync(domains: []) }
    }

    func tick() {
        ticks += 1
        let now = System.monotonic()
        var hostsDirty = false

        for request in Store.drainRequests() {
            let before = session
            session = SessionLogic.apply(request, to: session, monotonic: now, bootID: System.bootID)
            if session != before {
                Store.save(session)
                hostsDirty = true
                log("accepted \(request.kind.rawValue) request")
            }
        }

        guard var s = session else {
            if ticks % 5 == 1 { Store.writeStatus(.idle) }
            return
        }

        s.advance(monotonic: now, bootID: System.bootID)
        if s.isOver {
            session = nil
            Store.save(nil)
            Hosts.sync(domains: [])
            enforcer.reset()
            Store.writeStatus(.idle)
            log("session finished")
            return
        }
        session = s

        enforcer.enforce(s.rules)
        if hostsDirty || ticks % 5 == 0 { Hosts.sync(domains: s.rules.domains) }
        if ticks % 10 == 0 { Store.save(s) }
        if ticks % 2 == 0 { Launchd.ensureLoaded(.guardian) }
        Store.writeStatus(Status(session: s))
    }
}

/// The second service. It enforces nothing itself; it keeps the main service installed
/// and keeps its own copy of the session, so removing one of the two is not enough.
final class GuardRunner: Runner {
    private var known: Session?
    private var ticks = 0

    func tick() {
        ticks += 1
        let now = System.monotonic()
        known?.advance(monotonic: now, bootID: System.bootID)
        if let k = known, k.isOver { known = nil }
        guard ticks % 2 == 0 else { return }

        let onDisk = Store.loadSession()
        switch (known, onDisk) {
        case (nil, let disk?):
            var s = disk
            s.advance(monotonic: now, bootID: System.bootID)
            known = s.isOver ? nil : s
        case (let k?, let disk?):
            if disk.remainingSeconds >= k.remainingSeconds - 30 {
                // Normal drift or an extension: follow the main service.
                var s = disk
                s.advance(monotonic: now, bootID: System.bootID)
                known = s
            } else {
                log("session file was shortened, restoring it")
                Store.save(k)
            }
        case (let k?, nil):
            // The main service deletes the file only when the time is up.
            if k.remainingSeconds > 5 {
                log("session file disappeared, restoring it")
                Store.save(k)
            }
        case (nil, nil):
            break
        }

        if known != nil { Launchd.ensureLoaded(.main) }
    }
}
