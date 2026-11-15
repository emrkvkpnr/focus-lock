# FocusLock

Sperrt auf dem Mac Apps und Webseiten für eine feste Dauer. Eine laufende Sperre lässt sich nicht beenden: kein Stopp-Knopf, kein Passwort, kein Code. Sie lässt sich nur verlängern.

Stand: erste Version, noch nicht auf einem Mac gebaut oder getestet.

## Aufbau

| Teil | Ort | Aufgabe |
| --- | --- | --- |
| `FocusLockCore` | `Sources/FocusLockCore` | Regeln ohne Systemzugriff: Sitzungsuhr, App-Entscheidung, hosts-Text. Mit Tests. |
| `focuslockd` | `Sources/focuslockd` | Dienst mit Root-Rechten. Läuft zweimal: als Sperr-Dienst und als Wächter. |
| `FocusLock` | `Sources/FocusLock` | Menüleisten-App (SwiftUI): Profile, Dauer, Countdown. |

Die App hat selbst keine Rechte. Sie legt eine Anfrage in `/Library/Application Support/FocusLock/requests` ab; der Dienst kennt nur `start` und `extend`.

## Wie gesperrt wird

- **Apps:** Der Dienst liest jede Sekunde die Prozessliste und beendet, was das Profil nicht zulässt. Im Modus "nur erlaubt" bleiben Systemprozesse und Menüleisten-Helfer ohne Dock-Symbol unberührt. Die Systemeinstellungen sind während jeder Sperre geschlossen.
- **Webseiten:** Einträge in `/etc/hosts`, gelten für alle Browser. Der Dienst stellt sie alle fünf Sekunden wieder her.
- **Uhr:** Gezählt wird mit einer monotonen Uhr. Datum umstellen ändert nichts, Zeit im ausgeschalteten Zustand zählt nicht, ein Neustart beendet nichts.
- **Selbstschutz:** Sperr-Dienst und Wächter laden sich gegenseitig neu und stellen Sitzungsdatei und launchd-Einträge wieder her.

## Grenzen

- Wer Administrator ist und es darauf anlegt (Recovery-Modus, beide Dienste gleichzeitig entfernen), kommt heraus. Das Ziel ist, dass es für einen spontanen Impuls zu umständlich ist.
- Safari mit iCloud Privat-Relay umgeht `/etc/hosts`. Dann Safari als App sperren oder Privat-Relay ausschalten.
- Gesperrt werden die Domain und `www.`, keine weiteren Subdomains.

## Installieren

```bash
./scripts/install.sh
```

Braucht macOS 13 oder neuer und die Xcode Command Line Tools. Entfernen (nur ohne laufende Sperre):

```bash
./scripts/uninstall.sh
```

## Tests

```bash
swift test
```
