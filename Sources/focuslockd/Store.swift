import Darwin
import FocusLockCore
import Foundation

enum Store {
    static func prepare() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: Paths.requests, withIntermediateDirectories: true)
        } catch {
            log("could not create \(Paths.requests): \(error)")
        }
        chmod(Paths.base, 0o755)
        chmod(Paths.requests, 0o1777)
    }

    static func loadSession() -> Session? {
        guard let data = FileManager.default.contents(atPath: Paths.session) else { return nil }
        do {
            return try JSONDecoder().decode(Session.self, from: data)
        } catch {
            log("unreadable session file: \(error)")
            return nil
        }
    }

    static func save(_ session: Session?) {
        guard let session else {
            unlink(Paths.session)
            return
        }
        write(session, to: Paths.session)
    }

    static func writeStatus(_ status: Status) {
        write(status, to: Paths.status)
    }

    private static func write<T: Encodable>(_ value: T, to path: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            chmod(path, 0o644)
        } catch {
            log("could not write \(path): \(error)")
        }
    }

    /// Reads and removes every pending request. Files come from an unprivileged user, so:
    /// no symlinks, regular files only, small size, strict decoding.
    static func drainRequests() -> [Request] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: Paths.requests) else { return [] }
        var out: [Request] = []
        for name in names.sorted() where name.hasSuffix(".json") {
            let path = Paths.requests + "/" + name
            defer { unlink(path) }
            let fd = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
            guard fd >= 0 else { continue }
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            var st = stat()
            guard fstat(fd, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG, st.st_size <= 65_536 else { continue }
            let data = handle.readDataToEndOfFile()
            do {
                out.append(try JSONDecoder().decode(Request.self, from: data))
            } catch {
                log("ignored malformed request \(name): \(error)")
            }
        }
        return out
    }
}
