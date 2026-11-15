import XCTest
@testable import FocusLockCore

final class CoreTests: XCTestCase {
    private let rules = Rules(mode: .block, apps: ["com.apple.Safari"], domains: ["amazon.de"])

    private func started(seconds: Int = 7200) -> Session {
        SessionLogic.apply(Request(kind: .start, seconds: seconds, rules: rules, profileName: "Lernen"),
                           to: nil, monotonic: 100, bootID: "A")!
    }

    func testClockCountsDownOnSameBoot() {
        var s = started()
        s.advance(monotonic: 160, bootID: "A")
        XCTAssertEqual(s.remainingSeconds, 7140)
    }

    func testRebootCreditsNothing() {
        var s = started()
        s.advance(monotonic: 5, bootID: "B")
        XCTAssertEqual(s.remainingSeconds, 7200)
        s.advance(monotonic: 15, bootID: "B")
        XCTAssertEqual(s.remainingSeconds, 7190)
    }

    func testMonotonicGoingBackwardsCreditsNothing() {
        var s = started()
        s.advance(monotonic: 50, bootID: "A")
        XCTAssertEqual(s.remainingSeconds, 7200)
    }

    func testSecondStartCannotReplaceRunningSession() {
        let s = started()
        let other = Request(kind: .start, seconds: 60, rules: Rules(mode: .block, apps: ["x"]), profileName: "kurz")
        XCTAssertEqual(SessionLogic.apply(other, to: s, monotonic: 200, bootID: "A"), s)
    }

    func testExtendOnlyAddsAndIsCapped() {
        let s = started()
        let longer = SessionLogic.apply(Request(kind: .extend, seconds: 900), to: s, monotonic: 100, bootID: "A")!
        XCTAssertEqual(longer.remainingSeconds, 8100)
        let negative = SessionLogic.apply(Request(kind: .extend, seconds: -900), to: s, monotonic: 100, bootID: "A")!
        XCTAssertEqual(negative.remainingSeconds, 7200)
        let huge = SessionLogic.apply(Request(kind: .extend, seconds: 999_999), to: s, monotonic: 100, bootID: "A")!
        XCTAssertEqual(huge.remainingSeconds, Double(Limits.maxSeconds))
    }

    func testStartRejectsTooShortAndEmptyBlock() {
        XCTAssertNil(SessionLogic.apply(Request(kind: .start, seconds: 10, rules: rules), to: nil, monotonic: 0, bootID: "A"))
        XCTAssertNil(SessionLogic.apply(Request(kind: .start, seconds: 600, rules: Rules(mode: .block)), to: nil, monotonic: 0, bootID: "A"))
        XCTAssertNil(SessionLogic.apply(Request(kind: .start, seconds: 600), to: nil, monotonic: 0, bootID: "A"))
    }

    func testDomainNormalization() {
        XCTAssertEqual(Domain.normalize(" https://www.Amazon.de/gp/cart?x=1 "), "amazon.de")
        XCTAssertEqual(Domain.normalize("youtube.com"), "youtube.com")
        XCTAssertNil(Domain.normalize("localhost"))
        XCTAssertNil(Domain.normalize("bad domain.com"))
        XCTAssertNil(Domain.normalize("evil.com\n127.0.0.1 x"))
        XCTAssertNil(Domain.normalize(""))
    }

    func testHostsApplyAndStripRoundTrip() {
        let original = "127.0.0.1 localhost\n::1 localhost\n"
        let blocked = HostsFile.apply(original, domains: ["amazon.de"])
        XCTAssertTrue(blocked.contains("0.0.0.0 amazon.de\n"))
        XCTAssertTrue(blocked.contains("0.0.0.0 www.amazon.de\n"))
        XCTAssertEqual(HostsFile.strip(blocked), original)
        XCTAssertEqual(HostsFile.apply(blocked, domains: ["amazon.de"]), blocked)
        XCTAssertEqual(HostsFile.apply(blocked, domains: []), original)
    }

    func testOuterBundle() {
        XCTAssertEqual(AppPolicy.outerBundle(ofExecutable:
            "/Applications/Discord.app/Contents/Frameworks/Discord Helper.app/Contents/MacOS/Discord Helper"),
            "/Applications/Discord.app")
        XCTAssertNil(AppPolicy.outerBundle(ofExecutable: "/usr/bin/curl"))
    }

    func testAllowOnlyPolicy() {
        let allow = Rules(mode: .allowOnly, apps: ["com.apple.Terminal"])
        XCTAssertFalse(AppPolicy.shouldClose(bundlePath: "/System/Applications/Utilities/Terminal.app",
                                             bundleID: "com.apple.Terminal", isAgent: false, rules: allow))
        XCTAssertTrue(AppPolicy.shouldClose(bundlePath: "/Applications/Discord.app",
                                            bundleID: "com.hnc.Discord", isAgent: false, rules: allow))
        XCTAssertTrue(AppPolicy.shouldClose(bundlePath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
                                            bundleID: "com.apple.Safari", isAgent: false, rules: allow))
        XCTAssertFalse(AppPolicy.shouldClose(bundlePath: "/System/Library/CoreServices/Finder.app",
                                             bundleID: "com.apple.finder", isAgent: false, rules: allow))
        XCTAssertFalse(AppPolicy.shouldClose(bundlePath: "/Applications/Rectangle.app",
                                             bundleID: "com.knollsoft.Rectangle", isAgent: true, rules: allow))
        XCTAssertFalse(AppPolicy.shouldClose(bundlePath: "/Applications/FocusLock.app",
                                             bundleID: AppPolicy.ownAppID, isAgent: false, rules: allow))
    }

    func testBlockPolicyAndSystemSettings() {
        XCTAssertTrue(AppPolicy.shouldClose(bundlePath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
                                            bundleID: "com.apple.Safari", isAgent: false, rules: rules))
        XCTAssertFalse(AppPolicy.shouldClose(bundlePath: "/Applications/RemNote.app",
                                             bundleID: "io.remnote", isAgent: false, rules: rules))
        XCTAssertTrue(AppPolicy.shouldClose(bundlePath: "/System/Applications/System Settings.app",
                                            bundleID: "com.apple.systempreferences", isAgent: false, rules: rules))
    }
}
