import Foundation

public enum Mode: String, Codable, CaseIterable, Sendable {
    /// Only the listed apps may run; every other regular app is closed.
    case allowOnly
    /// The listed apps are closed; everything else may run.
    case block
}

public struct Rules: Codable, Equatable, Sendable {
    public var mode: Mode
    /// Bundle identifiers.
    public var apps: [String]
    /// Domains that are blocked in both modes.
    public var domains: [String]

    public init(mode: Mode, apps: [String] = [], domains: [String] = []) {
        self.mode = mode
        self.apps = apps
        self.domains = domains
    }

    /// Deduplicated apps, cleaned and deduplicated domains.
    public func normalized() -> Rules {
        var seenApps = Set<String>()
        let cleanApps = apps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seenApps.insert($0).inserted }
        var seenDomains = Set<String>()
        let cleanDomains = domains
            .compactMap(Domain.normalize)
            .filter { seenDomains.insert($0).inserted }
        return Rules(mode: mode, apps: cleanApps, domains: cleanDomains)
    }

    /// A block profile without any entry would lock nothing.
    public var isEmptyBlock: Bool {
        let n = normalized()
        return n.mode == .block && n.apps.isEmpty && n.domains.isEmpty
    }
}

public enum Domain {
    /// "https://www.Amazon.de/foo" -> "amazon.de". Returns nil for anything that is not a plain host name.
    public static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for scheme in ["https://", "http://"] where s.hasPrefix(scheme) {
            s.removeFirst(scheme.count)
        }
        if let cut = s.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" || $0 == ":" }) {
            s = String(s[..<cut])
        }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard !s.isEmpty, s.count <= 253, s.contains("."),
              s.allSatisfy(allowed.contains),
              !s.hasPrefix("."), !s.hasSuffix("."), !s.hasPrefix("-"), !s.contains("..")
        else { return nil }
        return s
    }
}

public enum Limits {
    public static let minSeconds = 60
    public static let maxSeconds = 8 * 3600
}

public struct Request: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case start, extend }
    public var kind: Kind
    public var seconds: Int
    public var rules: Rules?
    public var profileName: String?

    public init(kind: Kind, seconds: Int, rules: Rules? = nil, profileName: String? = nil) {
        self.kind = kind
        self.seconds = seconds
        self.rules = rules
        self.profileName = profileName
    }
}

public struct Session: Codable, Equatable, Sendable {
    public var profileName: String
    public var rules: Rules
    public var totalSeconds: Double
    public var remainingSeconds: Double
    /// Boot the monotonic reading belongs to. Monotonic time restarts on every boot.
    public var bootID: String
    public var lastMonotonic: Double

    public init(profileName: String, rules: Rules, totalSeconds: Double, remainingSeconds: Double,
                bootID: String, lastMonotonic: Double) {
        self.profileName = profileName
        self.rules = rules
        self.totalSeconds = totalSeconds
        self.remainingSeconds = remainingSeconds
        self.bootID = bootID
        self.lastMonotonic = lastMonotonic
    }

    public var isOver: Bool { remainingSeconds <= 0 }

    /// Counts down by monotonic time only. The wall clock is never consulted, so changing the
    /// system date does nothing. Time while the Mac was switched off is not credited.
    public mutating func advance(monotonic: Double, bootID: String) {
        if bootID == self.bootID {
            let delta = monotonic - lastMonotonic
            if delta > 0 { remainingSeconds -= delta }
        }
        self.bootID = bootID
        lastMonotonic = monotonic
    }
}

public enum SessionLogic {
    /// The only way a session changes besides the clock. There is deliberately no "stop".
    public static func apply(_ request: Request, to session: Session?, monotonic: Double, bootID: String) -> Session? {
        switch request.kind {
        case .start:
            if let session, !session.isOver { return session }
            guard let rules = request.rules?.normalized(), !rules.isEmptyBlock,
                  request.seconds >= Limits.minSeconds else { return session }
            let seconds = Double(min(request.seconds, Limits.maxSeconds))
            let name = (request.profileName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Session(profileName: String(name.prefix(60)), rules: rules, totalSeconds: seconds,
                           remainingSeconds: seconds, bootID: bootID, lastMonotonic: monotonic)
        case .extend:
            guard var s = session, !s.isOver, request.seconds > 0 else { return session }
            let room = Double(Limits.maxSeconds) - s.remainingSeconds
            let add = min(Double(request.seconds), max(0, room))
            s.remainingSeconds += add
            s.totalSeconds += add
            return s
        }
    }
}

public struct Status: Codable, Equatable, Sendable {
    public var active: Bool
    public var remainingSeconds: Int
    public var totalSeconds: Int
    public var profileName: String?
    public var rules: Rules?

    public init(active: Bool, remainingSeconds: Int = 0, totalSeconds: Int = 0,
                profileName: String? = nil, rules: Rules? = nil) {
        self.active = active
        self.remainingSeconds = remainingSeconds
        self.totalSeconds = totalSeconds
        self.profileName = profileName
        self.rules = rules
    }

    public static let idle = Status(active: false)

    public init(session: Session) {
        self.init(active: true,
                  remainingSeconds: max(1, Int(session.remainingSeconds.rounded(.up))),
                  totalSeconds: Int(session.totalSeconds),
                  profileName: session.profileName, rules: session.rules)
    }
}
