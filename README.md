# Tripboard – Travel Planner

Ein Flutter-Reiseplaner für Android (iOS-fähig). Er bietet drei Sichten auf dieselben Daten:

- **Canvas / Notizen**: eine freie Fläche und ein Keep-artiges Raster für Notizen, Checklisten, Links, Bilder und Tickets.
- **Zeitplan**: die Ebenen Orte → Transport → Unterkünfte (in Nächten) → Aktivitäten. Verschieben per Long-Press und Ziehen; nachfolgende Elemente rutschen mit, fixe Termine bleiben stehen. Konflikte, freie Tage und Nächte ohne Unterkunft werden angezeigt.
- **Karte**: MapLibre mit OpenStreetMap-Stil von OpenFreeMap, kein API-Key nötig.

Alle Daten liegen lokal (SQLite über drift). Einzelne Reisen oder alle Reisen auf einmal lassen sich als ZIP exportieren; „Backup importieren“ nimmt beide Varianten an. Zusätzlich schreibt die App beim Start und beim Wechsel in den Hintergrund ein Backup aller Reisen, wenn das letzte älter als 24 Stunden ist. Diese Backups liegen im App-Ordner auf dem externen Speicher (`Android/data/<App>/files/backups`), die letzten 7 bleiben erhalten. Unter ⋮ → Backups & Wiederherstellen sieht man das letzte Backup und kann eines zurückspielen. Die Android-Cloud-Sicherung umfasst Datenbank und Anhänge (`android/app/src/main/res/xml/`). Gelöschte Reisen liegen 30 Tage im Papierkorb (⋮ → Papierkorb) und werden danach beim App-Start endgültig entfernt, samt Anhängen. Inhalte, die man aus anderen Apps „teilt“, landen als Notiz in einer Reise.

## Mit Claude planen

Über **⋮ → Mit Claude planen …** (in der Reiseliste oder in einer Reise) kopiert die App eine Anleitung zum Austauschformat `tripboard-plan`, auf Wunsch zusammen mit dem aktuellen Plan. Den Text fügt man in der Claude-App ein und lässt Claude mit Websuche planen. Claudes Antwort endet mit einem JSON-Block. Diesen kopiert man und übernimmt ihn in der App über „Plan aus Zwischenablage übernehmen“; alternativ teilt man die Antwort direkt an Tripboard. Vor dem Übernehmen zeigt die App eine Vorschau mit den Änderungen und Hinweisen. Fehlende Koordinaten sucht sie über OpenStreetMap. Der Import in eine bestehende Reise lässt sich als ein Schritt rückgängig machen.

Das Format ist in [`assets/plan_format.md`](assets/plan_format.md) beschrieben, die Logik steckt in `lib/domain/plan_exchange.dart`. Bekannte `ref`s aktualisieren bestehende Einträge, unbekannte legen neue an. Gelöscht wird nur, was unter `remove` steht.

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

Signiert wird mit dem Upload-Key aus `android/key.properties`. Die Datei liegt nicht im Repo, der Keystore liegt unter `~/tripboard-upload-keystore.jks`. Fehlt die Datei, wird mit dem Debug-Key signiert. Das App-Icon entsteht aus `assets/icon/*.svg` (als PNG rendern, dann `dart run flutter_launcher_icons`). Die Play-Store-Grafiken liegen in `store/play/`; der Feature-Banner wird aus `store/feature-graphic.html` gerendert (Befehl steht in der Datei).
