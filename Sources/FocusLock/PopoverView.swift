import FocusLockCore
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: model.isActive ? "lock.fill" : "lock.open")
                    .foregroundStyle(Theme.accent)
                Text("FocusLock").font(Theme.title(15))
                Spacer()
            }

            if let status = model.status {
                if status.active {
                    ActiveView(status: status)
                } else {
                    IdleView()
                }
            } else {
                ServiceMissingView()
            }

            if let error = model.errorText {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Profile bearbeiten") {
                    openWindow(id: "profiles")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("FocusLock beenden") { NSApp.terminate(nil) }
                    .help("Schließt nur diese Anzeige. Eine laufende Sperre bleibt bestehen.")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 320)
    }
}

private struct ServiceMissingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Der Sperr-Dienst läuft nicht").font(Theme.title(13))
            Text("Installiere ihn einmalig im Terminal mit scripts/install.sh aus dem Projektordner.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ActiveView: View {
    @EnvironmentObject private var model: AppModel
    let status: Status

    private var progress: Double {
        guard status.totalSeconds > 0 else { return 0 }
        return 1 - Double(status.remainingSeconds) / Double(status.totalSeconds)
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.accentSoft, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.002, progress))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                VStack(spacing: 2) {
                    Text(Format.clock(status.remainingSeconds)).font(Theme.digits(30))
                    Text("verbleibend").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 168, height: 168)
            .frame(maxWidth: .infinity)

            VStack(spacing: 3) {
                if let name = status.profileName, !name.isEmpty {
                    Text(name).font(Theme.title(14))
                }
                if let rules = status.rules {
                    Text(Format.summary(rules)).font(.callout).foregroundStyle(.secondary)
                }
                Text("Frei ab \(Date().addingTimeInterval(Double(status.remainingSeconds)).formatted(date: .omitted, time: .shortened)) Uhr")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("15 Minuten verlängern") { model.extend(minutes: 15) }
                .buttonStyle(QuietButton())

            Text("Diese Sperre lässt sich nicht vorzeitig beenden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct IdleView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirming = false

    private let presets = [25, 50, 90, 120]

    private var canStart: Bool {
        guard let p = model.selected else { return false }
        return !p.rules.isEmptyBlock
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Profil").font(.caption).foregroundStyle(.secondary)
                Picker("Profil", selection: $model.selectedID) {
                    ForEach(model.profiles) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                if let p = model.selected {
                    Text(Format.summary(p.rules)).font(.callout).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Dauer").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { value in
                        Button {
                            model.minutes = value
                        } label: {
                            Text("\(value)")
                                .font(Theme.digits(13))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(model.minutes == value ? Theme.accent : Theme.accentSoft))
                                .foregroundStyle(model.minutes == value ? Color.white : Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Stepper(value: $model.minutes, in: 5...(Limits.maxSeconds / 60), step: 5) {
                    Text(Format.duration(minutes: model.minutes)).font(Theme.digits(13))
                }
            }

            if model.isStarting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Apps werden geschlossen").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else if confirming {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(Format.duration(minutes: model.minutes)) sperren?").font(Theme.title(14))
                    Text("Es gibt keinen Abbruch, kein Passwort und keinen Code. Andere Apps werden geschlossen, nicht gespeicherte Änderungen dort gehen verloren.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Zurück") { confirming = false }.buttonStyle(QuietButton())
                        Button("Jetzt sperren") {
                            confirming = false
                            model.start()
                        }
                        .buttonStyle(PrimaryButton())
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.accentSoft))
            } else {
                Button("Sperre starten") { confirming = true }
                    .buttonStyle(PrimaryButton())
                    .disabled(!canStart)
            }
        }
    }
}
