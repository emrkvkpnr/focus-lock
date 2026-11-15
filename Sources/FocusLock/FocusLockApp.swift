import SwiftUI

@main
struct FocusLockApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(model)
        } label: {
            if let status = model.status, status.active {
                Label(Format.clock(status.remainingSeconds), systemImage: "lock.fill")
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
            } else {
                Image(systemName: "lock.open")
            }
        }
        .menuBarExtraStyle(.window)

        Window("Profile", id: "profiles") {
            ProfilesView()
                .environmentObject(model)
                .frame(minWidth: 680, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
    }
}

enum Theme {
    /// A calm indigo. The only accent in the app.
    static let accent = Color(red: 0.37, green: 0.42, blue: 0.78)
    static let accentSoft = accent.opacity(0.14)
    static let corner: CGFloat = 12

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func digits(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .rounded).monospacedDigit() }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.accent.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)))
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.accentSoft.opacity(configuration.isPressed ? 0.6 : 1)))
    }
}
