import FocusLockCore
import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingID: UUID?
    @State private var installed: [InstalledApp] = []

    var body: some View {
        NavigationSplitView {
            List(selection: $editingID) {
                ForEach(model.profiles) { profile in
                    Text(profile.name.isEmpty ? "Ohne Namen" : profile.name).tag(profile.id)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button {
                        let profile = Profile(name: "Neues Profil", rules: Rules(mode: .block))
                        model.profiles.append(profile)
                        editingID = profile.id
                    } label: { Image(systemName: "plus") }
                    Button {
                        guard let id = editingID, model.profiles.count > 1 else { return }
                        model.profiles.removeAll { $0.id == id }
                        editingID = model.profiles.first?.id
                        if model.selectedID == id, let first = model.profiles.first { model.selectedID = first.id }
                    } label: { Image(systemName: "minus") }
                    .disabled(model.profiles.count <= 1 || editingID == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(10)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if let index = model.profiles.firstIndex(where: { $0.id == editingID }) {
                ProfileEditor(profile: $model.profiles[index], installed: installed)
            } else {
                Text("Wähle ein Profil").foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if editingID == nil { editingID = model.selectedID }
            installed = InstalledApp.scan()
        }
    }
}

private struct ProfileEditor: View {
    @Binding var profile: Profile
    let installed: [InstalledApp]
    @State private var search = ""

    private var visibleApps: [InstalledApp] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? installed : installed.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var domainsText: Binding<String> {
        Binding(
            get: { profile.rules.domains.joined(separator: "\n") },
            // Empty lines are kept while typing and dropped when a session starts.
            set: { profile.rules.domains = $0.components(separatedBy: "\n") }
        )
    }

    private func isOn(_ app: InstalledApp) -> Binding<Bool> {
        Binding(
            get: { profile.rules.apps.contains(app.id) },
            set: { on in
                if on {
                    if !profile.rules.apps.contains(app.id) { profile.rules.apps.append(app.id) }
                } else {
                    profile.rules.apps.removeAll { $0 == app.id }
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $profile.name)
                .textFieldStyle(.roundedBorder)
                .font(Theme.title(15))

            Picker("Modus", selection: $profile.rules.mode) {
                Text("Nur diese Apps erlauben").tag(Mode.allowOnly)
                Text("Diese Apps sperren").tag(Mode.block)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(profile.rules.mode == .allowOnly
                 ? "Alle anderen Apps mit Dock-Symbol werden geschlossen. Menüleisten-Helfer laufen weiter."
                 : "Nur die markierten Apps werden geschlossen. Alles andere bleibt nutzbar.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.rules.mode == .allowOnly ? "Erlaubte Apps" : "Gesperrte Apps")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Suchen", text: $search).textFieldStyle(.roundedBorder)
                    List(visibleApps) { app in
                        Toggle(isOn: isOn(app)) {
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(app.name)
                            }
                        }
                    }
                    .listStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Gesperrte Webseiten, eine pro Zeile")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: domainsText)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    Text("Beispiel: amazon.de")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(width: 230)
            }
        }
        .padding(20)
    }
}
