# Reiseplaner

Ein Flutter-Reiseplaner für Android (iOS-fähig). Er bietet drei Sichten auf dieselben Daten:

- **Canvas / Notizen**: eine freie Fläche und ein Keep-artiges Raster für Notizen, Checklisten, Links, Bilder und Tickets.
- **Zeitplan**: die Ebenen Orte → Transport → Unterkünfte (in Nächten) → Aktivitäten. Verschieben per Long-Press und Ziehen; nachfolgende Elemente rutschen mit, fixe Termine bleiben stehen. Konflikte, freie Tage und Nächte ohne Unterkunft werden angezeigt.
- **Karte**: MapLibre mit OpenStreetMap-Stil von OpenFreeMap, kein API-Key nötig.

Alle Daten liegen lokal (SQLite über drift). Backups lassen sich als ZIP exportieren und importieren. Inhalte, die man aus anderen Apps „teilt“, landen als Notiz in einer Reise.

## Struktur

| Pfad | Inhalt |
| --- | --- |
| `lib/domain/` | Modelle, Zeitmodell, `scheduler.dart` (Verschiebe-Logik) und `analysis.dart` (Konflikte, Lücken). Reines Dart. |
| `lib/data/` | drift-Datenbank, Repository, Anhänge, Ortssuche (Photon), Link-Vorschau, Backup |
| `lib/state/` | Riverpod-Provider, gemeinsamer UI-Zustand, Undo |
| `lib/ui/` | Reiseliste, Reise-Shell, Zeitplan, Karte, Canvas, Notizen, Editoren |

## Entwickeln

```bash
flutter pub get
dart run build_runner build   # nach Änderungen an lib/data/db.dart
flutter test
flutter run
```

## Release

```bash
flutter build apk --release --split-per-abi   # kleinere APKs pro Architektur
flutter build appbundle --release             # für den Play Store
```

Signiert wird mit dem Upload-Key aus `android/key.properties`. Die Datei liegt nicht im Repo, der Keystore liegt unter `~/travelplanner-upload-keystore.jks`. Fehlt die Datei, wird mit dem Debug-Key signiert. Das App-Icon entsteht aus `assets/icon/*.svg` (als PNG rendern, dann `dart run flutter_launcher_icons`).
