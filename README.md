# Tripboard – Travel Planner

Ein Flutter-Reiseplaner für Android (iOS-fähig). Er bietet vier Sichten auf dieselben Daten und eine Agenda für unterwegs:

- **Canvas / Notizen**: eine freie Fläche und ein Keep-artiges Raster für Notizen, Checklisten, Links, Bilder und Tickets. Wischen verschiebt die Fläche; Elemente werden per Long-Press und Ziehen bewegt.
- **Zeitplan**: die Ebenen Orte → Transport → Unterkünfte (in Nächten) → Aktivitäten. Verschieben per Long-Press und Ziehen, Beginn/Ende über die Griffe am ausgewählten Block; nachfolgende Elemente rutschen mit, fixe Termine bleiben stehen. Konflikte, freie Tage und Nächte ohne Unterkunft werden angezeigt. Gibt es für eine solche Nacht schon Unterkunfts-Optionen, zeigt die Markierung deren Anzahl und bietet sie zuerst zur Wahl an; jede Option lässt sich auch in ihrem Detailblatt wählen oder als gebucht markieren. Fehlt zwischen zwei aufeinanderfolgenden Orten ein Transport, zeigt die Transport-Ebene dort „+ Transport“; ein Tipp öffnet den Editor mit beiden Orten und passender Abfahrt. Im Detailblatt eines Orts legen „Transport hierher“ und „Transport weiter“ die Verbindung zum vorigen bzw. nächsten Ort an. Transporte haben optionale Ticketdaten (Abfahrts-/Ankunftsbahnhof bzw. -flughafen, Zug-/Flugnummer, Sitzplatz/Gleis, Buchungsnummer); Detailblatt und Heute-Sicht zeigen sie wie auf einer Bordkarte, die Buchungsnummer kopiert ein Tipp.
- **Karte**: MapLibre mit OpenStreetMap-Stil von OpenFreeMap, kein API-Key nötig. Long-Press auf die Karte legt dort etwas an. Ein Tipp auf einen Kreis, ein Label oder knapp daneben öffnet das Detailblatt; die Karte behält dabei den Zoom und schwenkt nur, wenn das Element außerhalb des Ausschnitts liegt. Unterkünfte und Aktivitäten ohne eigene Koordinaten liegen im Kreis um ihren Ort statt verdeckt darunter. „Mein Standort“ fragt nach der Standort-Berechtigung, zeigt die Position als blauen Punkt und folgt ihr, solange die Karte sichtbar ist. „Navigation“ im Detailblatt übergibt den Ort (bei Transporten den Abfahrtsbahnhof bzw. -ort) per `geo:`-Link an eine Karten-App, ersatzweise an Google Maps im Browser. Über den Knopf „Karte offline speichern“ lädt die App die Gegend der Reise (Übersicht plus Straßenebene um jeden Ort) für unterwegs herunter. Ohne Netz und ohne gespeicherte Karte zeigt sie einen Hinweis und die Orte der Reise als Liste.
- **Heute**: die Agenda für unterwegs. Oben eine Leiste mit allen Reisetagen (Heute, Morgen, Gestern, sonst das Datum), darunter der gewählte Tag: wo man ist, die Unterkunft mit Adresse und Check-in/-out (oder der Hinweis, dass für die Nacht noch ein Bett fehlt, samt Optionen), der nächste Transport mit Abfahrt und Ankunft und das Programm des Tages. Anhänge eines Elements und der mit ihm verknüpften Notizen (Tickets) öffnen sich mit einem Tipp. „Springe zu heute“ führt von einem anderen Tag zurück. Läuft eine Reise gerade (Startdatum gesetzt, heute liegt in der Reise), öffnet sie direkt in dieser Sicht. Die Logik steckt in `lib/domain/agenda.dart`; alles kommt aus den lokalen Daten, die Sicht funktioniert also offline.

**Zeitzonen (optional):** Jeder Ort kann eine IANA-Zeitzone bekommen (z. B. `Asia/Colombo`), die Reise eine Heimat-Zeitzone (Reise bearbeiten) für alles ohne eigene Zone. Alle Zeiten bleiben Ortszeiten: Unterkünfte und Aktivitäten gelten in der Zone ihres Orts, ein Transport fährt in der Zone des Abfahrtsorts ab und kommt in der des Zielorts an (im Editor einzeln überschreibbar). Für Vergleiche rechnet die App in absolute Zeit um. So stimmen Flugdauern (FRA 21:30 → CMB 10:30 = 8 h 30 min), Reihenfolge und Konflikte, auch wenn ein Flug über die Datumsgrenze „früher“ landet, als er startet; Sommerzeit wird über das Startdatum berücksichtigt. Detailblatt, Editor und Heute-Sicht zeigen bei zonenübergreifenden Transporten die UTC-Versätze und die echte Dauer. Ohne Zonen verhält sich alles wie bisher. Die Zeitzonendaten liegen im Paket `timezone` bei, es braucht kein Netz. Die Logik steckt in `lib/domain/zones.dart`.

**Ortssuche:** Der Editor sucht Orte online über Photon (OpenStreetMap). Ohne Netz ist sie keine Sackgasse: Sie zeigt die zuletzt verwendeten Orte aus allen Reisen (ohne Papierkorb, beim Tippen gefiltert), erkennt eingefügte Google-Maps-, OpenStreetMap-, Apple-Maps- und `geo:`-Links sowie Koordinaten (`48.8584, 2.2945`, `48°51'30"N 2°17'40"E`, `N 48.85 E 2.29`), und ein Ort lässt sich auch nur mit Namen „ohne Koordinaten speichern“; er fehlt dann auf der Karte. Kurzlinks (`maps.app.goo.gl/…`) werden online aufgelöst. Findet die Suche nichts, sagt sie „Keine Treffer“. Die Logik steckt in `lib/domain/places.dart`.

Das Detailblatt eines Elements bietet Schnellaktionen: Gebucht an/aus, Fix an/aus, −1/+1 Tag (im aktuellen Verschiebe-Modus) und Löschen, alles mit Rückgängig. Die versteckten Gesten erklärt jede Sicht einmalig mit einem Tipp-Banner; die Bestätigungen liegen in den Shared Preferences, ⋮ → Tipps wieder anzeigen setzt sie zurück.

Alle Daten liegen lokal (SQLite über drift). Einzelne Reisen oder alle Reisen auf einmal lassen sich als ZIP exportieren; „Backup importieren“ nimmt beide Varianten an. Zusätzlich schreibt die App beim Start und beim Wechsel in den Hintergrund ein Backup aller Reisen, wenn das letzte älter als 24 Stunden ist. Diese Backups liegen im App-Ordner auf dem externen Speicher (`Android/data/<App>/files/backups`), die letzten 7 bleiben erhalten. Unter ⋮ → Backups & Wiederherstellen sieht man das letzte Backup und kann eines zurückspielen. Die Android-Cloud-Sicherung umfasst Datenbank und Anhänge (`android/app/src/main/res/xml/`). Gelöschte Reisen liegen 30 Tage im Papierkorb (⋮ → Papierkorb) und werden danach beim App-Start endgültig entfernt, samt Anhängen. Inhalte, die man aus anderen Apps „teilt“, landen als Notiz in einer Reise.

## Sprachen

Die App gibt es auf Englisch und Deutsch. Sie folgt der Gerätesprache (unter Android 13+ auch der Sprache, die man in den Systemeinstellungen nur für Tripboard wählt); jede andere Sprache fällt auf Englisch zurück. Alle Texte liegen in `lib/l10n/app_en.arb` (Vorlage) und `lib/l10n/app_de.arb`. Jeder neue Text kommt in beide Dateien, danach erzeugt `flutter gen-l10n` (oder `flutter pub get`/`flutter run`) die Klassen in `lib/l10n/`. Im Code holt man die Texte mit `context.l10n` (`lib/ui/common/l10n.dart`). Dort werden auch die sprachneutralen Werte aus `lib/domain` in Worte gefasst: Arten, Status, Verkehrsmittel, Konflikte (`Conflict` trägt Typ und Werte), Import-Hinweise (`PlanWarning`), Tage und Daten (über `intl` in der jeweiligen Sprache) sowie die Texte der Beispielreisen (`DemoTexts`). `lib/domain` bleibt so frei von Flutter und von deutschen Texten. Ein Test (`test/ui/l10n_test.dart`) prüft, dass beide ARB-Dateien dieselben Schlüssel und Platzhalter haben und dass in `lib/ui`, `lib/domain` und `lib/state` keine deutschen Literale mehr stehen.

## Mit Claude planen

Über **⋮ → Mit Claude planen …** (in der Reiseliste oder in einer Reise) kopiert die App eine Anleitung zum Austauschformat `tripboard-plan`, auf Wunsch zusammen mit dem aktuellen Plan. Den Text fügt man in der Claude-App ein und lässt Claude mit Websuche planen. Claudes Antwort endet mit einem JSON-Block. Diesen kopiert man und übernimmt ihn in der App über „Plan aus Zwischenablage übernehmen“; alternativ teilt man die Antwort direkt an Tripboard. Vor dem Übernehmen zeigt die App eine Vorschau mit den Änderungen und Hinweisen. Fehlende Koordinaten sucht sie über OpenStreetMap. Der Import in eine bestehende Reise lässt sich als ein Schritt rückgängig machen.

Das Format ist in [`assets/plan_format.md`](assets/plan_format.md) beschrieben, die Logik steckt in `lib/domain/plan_exchange.dart`. Bekannte `ref`s aktualisieren bestehende Einträge, unbekannte legen neue an. Gelöscht wird nur, was unter `remove` steht. Zeitzonen sind optional: `trip.tz` (Heimat-Zone), `tz` an Orten sowie `tz`/`endTz` an Transporten; die Zeiten sind immer Ortszeiten.

## Struktur

| Pfad | Inhalt |
| --- | --- |
| `lib/domain/` | Modelle, Zeitmodell, `zones.dart` (Zeitzonen), `scheduler.dart` (Verschiebe-Logik) und `analysis.dart` (Konflikte, Lücken). Reines Dart. |
| `lib/data/` | drift-Datenbank, Repository, Anhänge, Ortssuche (Photon), Link-Vorschau, Backup |
| `lib/state/` | Riverpod-Provider, gemeinsamer UI-Zustand, Undo |
| `lib/ui/` | Reiseliste, Reise-Shell, Zeitplan, Karte, Canvas, Notizen, Editoren |
| `lib/l10n/` | Texte auf Englisch und Deutsch (ARB) und die daraus erzeugten Klassen |

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
