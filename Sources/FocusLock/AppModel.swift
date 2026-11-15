import AppKit
import FocusLockCore
import Foundation

struct Profile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var rules: Rules

    static let defaults: [Profile] = [
        Profile(name: "Lernen",
                rules: Rules(mode: .allowOnly, apps: ["com.apple.Terminal"], domains: [])),
        Profile(name: "Ablenkungen sperren",
                rules: Rules(mode: .block,
                             apps: ["com.hnc.Discord"],
                             domains: ["amazon.de", "amazon.com", "youtube.com", "instagram.com",
                                       "reddit.com", "x.com", "twitter.com", "tiktok.com", "twitch.tv"])),
    ]
}

enum ClientError: LocalizedError {
    case serviceMissing
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .serviceMissing:
            return "Der Sperr-Dienst ist nicht installiert. Führe scripts/install.sh aus."
        case .writeFailed(let reason):
            return "Die Anfrage konnte nicht übergeben werden: \(reason)"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    /// nil: the service has never written a status, so it is not installed or not running.
    @Published private(set) var status: Status?
    @Published var profiles: [Profile] { didSet { saveProfiles() } }
    @Published var selectedID: UUID
    @Published var minutes = 120
    @Published private(set) var isStarting = false
    @Published var errorText: String?

    private var timer: Timer?
    private let profilesURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FocusLock", isDirectory: true)
        profilesURL = dir.appendingPathComponent("profiles.json")
        var loaded = Profile.defaults
        if let data = try? Data(contentsOf: profilesURL),
           let stored = try? JSONDecoder().decode([Profile].self, from: data), !stored.isEmpty {
            loaded = stored
        }
        profiles = loaded
        selectedID = loaded[0].id
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var selected: Profile? { profiles.first { $0.id == selectedID } ?? profiles.first }
    var isActive: Bool { status?.active ?? false }

    func refresh() {
        guard let data = FileManager.default.contents(atPath: Paths.status),
              let decoded = try? JSONDecoder().decode(Status.self, from: data) else {
            if status != nil { status = nil }
            return
        }
        if decoded != status { status = decoded }
    }

    func start() {
        guard let profile = selected, !isStarting, !isActive else { return }
        let rules = profile.rules.normalized()
        let request = Request(kind: .start, seconds: minutes * 60, rules: rules, profileName: profile.name)
        isStarting = true
        errorText = nil
        askAppsToQuit(rules)
        Task {
            // Give the apps a moment to close on their own before the service steps in.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            submit(request)
            isStarting = false
        }
    }

    func extend(minutes: Int) {
        guard isActive else { return }
        submit(Request(kind: .extend, seconds: minutes * 60))
    }

    private func submit(_ request: Request) {
        do {
            guard FileManager.default.fileExists(atPath: Paths.requests) else { throw ClientError.serviceMissing }
            let data = try JSONEncoder().encode(request)
            let name = UUID().uuidString
            let tmp = Paths.requests + "/" + name + ".tmp"
            do {
                try data.write(to: URL(fileURLWithPath: tmp))
                try FileManager.default.moveItem(atPath: tmp, toPath: Paths.requests + "/" + name + ".json")
            } catch {
                throw ClientError.writeFailed(error.localizedDescription)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func askAppsToQuit(_ rules: Rules) {
        for app in NSWorkspace.shared.runningApplications {
            guard let path = app.bundleURL?.path else { continue }
            if AppPolicy.shouldClose(bundlePath: path, bundleID: app.bundleIdentifier,
                                     isAgent: app.activationPolicy != .regular, rules: rules) {
                app.terminate()
            }
        }
    }

    private func saveProfiles() {
        do {
            try FileManager.default.createDirectory(at: profilesURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(profiles).write(to: profilesURL, options: .atomic)
        } catch {
            errorText = "Profile konnten nicht gespeichert werden: \(error.localizedDescription)"
        }
    }
}

struct InstalledApp: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String

    static func scan() -> [InstalledApp] {
        let fm = FileManager.default
        let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications",
                    "/System/Applications/Utilities",
                    "/System/Volumes/Preboot/Cryptexes/App/System/Applications",
                    NSHomeDirectory() + "/Applications"]
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for dir in dirs {
            guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in names where name.hasSuffix(".app") {
                let path = dir + "/" + name
                guard let id = Bundle(path: path)?.bundleIdentifier,
                      id != AppPolicy.ownAppID, !AppPolicy.alwaysClosed.contains(id),
                      seen.insert(id).inserted else { continue }
                var display = fm.displayName(atPath: path)
                if display.hasSuffix(".app") { display.removeLast(4) }
                apps.append(InstalledApp(id: id, name: display, path: path))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

enum Format {
    static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) Min." }
        return m == 0 ? "\(h) Std." : "\(h) Std. \(m) Min."
    }

    static func summary(_ rules: Rules) -> String {
        let n = rules.normalized()
        let sites = n.domains.isEmpty ? nil : "\(n.domains.count) Webseiten gesperrt"
        switch n.mode {
        case .allowOnly:
            let apps = n.apps.isEmpty ? "Alle Apps geschlossen" : "Nur \(n.apps.count) Apps erlaubt"
            return [apps, sites].compactMap { $0 }.joined(separator: ", ")
        case .block:
            let apps = n.apps.isEmpty ? nil : "\(n.apps.count) Apps gesperrt"
            let parts = [apps, sites].compactMap { $0 }
            return parts.isEmpty ? "Noch nichts ausgewählt" : parts.joined(separator: ", ")
        }
    }
}
