# Tripboard – Travel Planner

Ein Flutter-Reiseplaner für Android (iOS-fähig). Er bietet drei Sichten auf dieselben Daten:

- **Canvas / Notizen**: eine freie Fläche und ein Keep-artiges Raster für Notizen, Checklisten, Links, Bilder und Tickets. Wischen verschiebt die Fläche; Elemente werden per Long-Press und Ziehen bewegt.
- **Zeitplan**: die Ebenen Orte → Transport → Unterkünfte (in Nächten) → Aktivitäten. Verschieben per Long-Press und Ziehen, Beginn/Ende über die Griffe am ausgewählten Block; nachfolgende Elemente rutschen mit, fixe Termine bleiben stehen. Konflikte, freie Tage und Nächte ohne Unterkunft werden angezeigt. Gibt es für eine solche Nacht schon Unterkunfts-Optionen, zeigt die Markierung deren Anzahl und bietet sie zuerst zur Wahl an; jede Option lässt sich auch in ihrem Detailblatt wählen oder als gebucht markieren.
- **Karte**: MapLibre mit OpenStreetMap-Stil von OpenFreeMap, kein API-Key nötig. Long-Press auf die Karte legt dort etwas an.

Das Detailblatt eines Elements bietet Schnellaktionen: Gebucht an/aus, Fix an/aus, −1/+1 Tag (im aktuellen Verschiebe-Modus) und Löschen, alles mit Rückgängig. Die versteckten Gesten erklärt jede Sicht einmalig mit einem Tipp-Banner; die Bestätigungen liegen in den Shared Preferences, ⋮ → Tipps wieder anzeigen setzt sie zurück.

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

Datenbank-Migrationen: Ändert sich das Schema in `lib/data/db.dart`, wird `schemaVersion` erhöht, ein `fromXToY`-Schritt ergänzt und `dart run drift_dev make-migrations` ausgeführt. Das legt einen Schema-Snapshot in `drift_schemas/` ab und erzeugt `lib/data/db.steps.dart` sowie die Test-Helfer in `test/drift/` neu. Ändert sich das JSON-Layout der Modelle so, dass alte Daten falsch gelesen würden, wird `currentDocVersion` in `lib/data/doc_migrations.dart` erhöht und ein Schritt ergänzt. Gespeicherte Zeilen werden dann beim Öffnen umgeschrieben, Backups beim Import.

## Release

```bash
flutter build apk --release --split-per-abi   # kleinere APKs pro Architektur
flutter build appbundle --release             # für den Play Store
```

Signiert wird mit dem Upload-Key aus `android/key.properties`. Die Datei liegt nicht im Repo, der Keystore liegt unter `~/tripboard-upload-keystore.jks`. Fehlt die Datei, wird mit dem Debug-Key signiert. Das App-Icon entsteht aus `assets/icon/*.svg` (als PNG rendern, dann `dart run flutter_launcher_icons`). Die Play-Store-Grafiken liegen in `store/play/`; der Feature-Banner wird aus `store/feature-graphic.html` gerendert (Befehl steht in der Datei).
