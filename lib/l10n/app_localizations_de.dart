// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Tripboard';

  @override
  String get kindStay => 'Ort';

  @override
  String get kindTransport => 'Transport';

  @override
  String get kindAccommodation => 'Unterkunft';

  @override
  String get kindActivity => 'Aktivität';

  @override
  String get statusIdea => 'Idee';

  @override
  String get statusOption => 'Option';

  @override
  String get statusPlanned => 'Geplant';

  @override
  String get statusBooked => 'Gebucht';

  @override
  String get modeTrain => 'Zug';

  @override
  String get modeBus => 'Bus';

  @override
  String get modePlane => 'Flug';

  @override
  String get modeFerry => 'Fähre';

  @override
  String get modeCar => 'Auto';

  @override
  String get modeTaxi => 'Taxi/Tuk-Tuk';

  @override
  String get modeWalk => 'Zu Fuß';

  @override
  String get modeOther => 'Sonstiges';

  @override
  String get shiftFollowing => 'Alles danach mitschieben';

  @override
  String get shiftPush => 'Nur schieben, wenn nötig';

  @override
  String get shiftSingle => 'Nur dieses Element';

  @override
  String get shiftFollowingShort => 'Alles danach';

  @override
  String get shiftPushShort => 'Puffer nutzen';

  @override
  String get shiftSingleShort => 'Nur dieses';

  @override
  String get dayPartMorning => 'Morgens';

  @override
  String get dayPartMidday => 'Mittags';

  @override
  String get dayPartAfternoon => 'Nachmittags';

  @override
  String get dayPartEvening => 'Abends';

  @override
  String get dayPartNight => 'Nachts';

  @override
  String get viewCanvas => 'Canvas';

  @override
  String get viewNotes => 'Notizen';

  @override
  String get viewTimeline => 'Zeitplan';

  @override
  String get viewMap => 'Karte';

  @override
  String dayNumber(int n) {
    return 'Tag $n';
  }

  @override
  String dayWithNumber(String date, int n) {
    return '$date (Tag $n)';
  }

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nächte',
      one: '1 Nacht',
    );
    return '$_temp0';
  }

  @override
  String hoursShort(int count) {
    return '${count}h';
  }

  @override
  String minutesShort(int count) {
    return '${count}min';
  }

  @override
  String layerLabel(int n, String kind) {
    return 'Ebene $n: $kind';
  }

  @override
  String conflictStaysOverlap(String item, String duration, String other) {
    return '„$item“ beginnt $duration bevor „$other“ endet';
  }

  @override
  String conflictLodgingOutsideStay(String item, String other) {
    return '„$item“ passt nicht zu den Tagen in $other';
  }

  @override
  String conflictActivityOutsideStay(String item, String other) {
    return '„$item“ liegt außerhalb des Aufenthalts in $other';
  }

  @override
  String conflictStayEndsAfterDeparture(String stay, String transport) {
    return '„$stay“ endet nach Abfahrt von „$transport“';
  }

  @override
  String conflictDaysBeforeDeparture(int days, String stay, String transport) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'liegen $days Tage',
      one: 'liegt 1 Tag',
    );
    return 'Zwischen „$stay“ und Abfahrt von „$transport“ $_temp0 ohne Ort';
  }

  @override
  String conflictStayStartsBeforeArrival(String stay, String transport) {
    return '„$stay“ beginnt vor Ankunft von „$transport“';
  }

  @override
  String conflictDaysAfterArrival(int days, String transport, String stay) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'liegen $days Tage',
      one: 'liegt 1 Tag',
    );
    return 'Zwischen Ankunft von „$transport“ und „$stay“ $_temp0 ohne Ort';
  }

  @override
  String fixPushLater(String title) {
    return '„$title“ nach hinten schieben';
  }

  @override
  String fixFitNightsToStay(String title) {
    return 'Nächte an $title anpassen';
  }

  @override
  String fixMoveIntoStay(String title) {
    return 'In $title verschieben';
  }

  @override
  String fixShortenToDeparture(String title) {
    return '„$title“ bis zur Abfahrt kürzen';
  }

  @override
  String fixExtendToDeparture(String title) {
    return '„$title“ bis zur Abfahrt verlängern';
  }

  @override
  String fixStartLaterAtArrival(String title) {
    return '„$title“ erst ab Ankunft';
  }

  @override
  String fixStartEarlierAtArrival(String title) {
    return '„$title“ ab Ankunft beginnen';
  }

  @override
  String warnRemoveUnknown(String value) {
    return 'remove: „$value“ gibt es nicht – ignoriert';
  }

  @override
  String warnDuplicateRef(String value) {
    return 'ref „$value“ kommt mehrfach vor – nur der erste Eintrag zählt';
  }

  @override
  String warnRefNotFound(String entry, String field, String value) {
    return '„$entry“: $field „$value“ nicht gefunden – Verknüpfung entfernt';
  }

  @override
  String warnUnknownKind(String entry, String value) {
    return '„$entry“: unbekannte Art „$value“ – übersprungen';
  }

  @override
  String warnMissingKind(String entry) {
    return '„$entry“: „kind“ fehlt – übersprungen';
  }

  @override
  String warnMissingTitle(String entry) {
    return 'Eintrag ohne Titel (ref $entry) – übersprungen';
  }

  @override
  String warnUnknownStatus(String entry, String value) {
    return '„$entry“: unbekannter Status „$value“ – ignoriert';
  }

  @override
  String warnUnknownMode(String entry, String value) {
    return '„$entry“: unbekanntes Verkehrsmittel „$value“ – „other“';
  }

  @override
  String warnSelfReference(String entry, String field) {
    return '„$entry“: $field verweist auf sich selbst – entfernt';
  }

  @override
  String warnStartOrEndOnly(String entry) {
    return '„$entry“: nur start oder end angegeben – bleibt ungeplant';
  }

  @override
  String warnEndBeforeStart(String entry) {
    return '„$entry“: end liegt vor start – Zeit nicht übernommen';
  }

  @override
  String warnUnsupportedNoteType(String entry, String value) {
    return '„$entry“: Notiztyp „$value“ wird nicht unterstützt – übersprungen';
  }

  @override
  String warnImageTypeFixed(String entry) {
    return '„$entry“: Bild-Notizen können den Typ nicht wechseln – Typ ignoriert';
  }

  @override
  String warnEmptyNote(String entry) {
    return 'Leere Notiz (ref $entry) – übersprungen';
  }

  @override
  String warnNotAnInteger(String field, String value) {
    return 'Reise: $field „$value“ ist keine ganze Zahl – ignoriert';
  }

  @override
  String warnInvalidStartDate(String value) {
    return 'Reise: startDate „$value“ ist kein Datum (YYYY-MM-DD) – ignoriert';
  }

  @override
  String warnDateNeedsStartDate(String entry, String field) {
    return '„$entry“: $field: Datum braucht ein Startdatum der Reise (trip.startDate) – ignoriert';
  }

  @override
  String warnInvalidMoment(
    String entry,
    String field,
    String value,
    String example,
  ) {
    return '„$entry“: $field: „$value“ unverständlich (erwartet $example) – ignoriert';
  }

  @override
  String planErrorInvalidJson(String detail) {
    return 'Kein gültiges JSON gefunden ($detail)';
  }

  @override
  String get planErrorNotAnObject =>
      'Kein Plan gefunden (JSON-Objekt erwartet)';

  @override
  String planErrorUnknownFormat(String detail, String expected) {
    return 'Unbekanntes Format „$detail“ (erwartet: $expected)';
  }

  @override
  String get planErrorNotAPlan =>
      'Kein Tripboard-Plan: „items“ oder „trip“ fehlt';

  @override
  String planErrorTooNew(String detail, int supported) {
    return 'Plan-Version $detail ist neuer als diese App (kann $supported)';
  }

  @override
  String get importedTripTitle => 'Importierte Reise';

  @override
  String get demoInterrailTitle => 'Interrail Frankreich & Spanien';

  @override
  String get demoAvignonNotes =>
      'Passt evtl. in die freien Tage zwischen Lyon und Barcelona';

  @override
  String get demoSagradaFamilia => 'Sagrada Família (gebucht)';

  @override
  String get demoPaellaCourse => 'Paella-Kochkurs';

  @override
  String get demoFlightHomeValencia => 'Rückflug Valencia → Zuhause';

  @override
  String get demoPassTitle => 'Interrail Pass';

  @override
  String get demoPassText =>
      'Global Pass: 7 Reisetage innerhalb 1 Monat.\nReservierungen für TGV & Euromed nötig!';

  @override
  String get demoPackingList => 'Packliste';

  @override
  String get demoPackingItems =>
      'Reisepass|Interrail-App offline|Adapter|Badesachen|Powerbank';

  @override
  String get demoReservationsLink => 'Interrail Reservierungen';

  @override
  String get demoFreeDaysTitle => 'Freie Tage 7–8';

  @override
  String get demoFreeDaysText =>
      'Ideen: Avignon, Montpellier oder Carcassonne?';

  @override
  String get demoSriLankaTitle => 'Sri Lanka 2,5 Wochen';

  @override
  String get demoYalaName => 'Yala Nationalpark';

  @override
  String get demoYalaNotes =>
      'Safari früh morgens – liegt zwischen Ella und Mirissa';

  @override
  String get demoFlightOut => 'Hinflug';

  @override
  String get demoTrainKandyElla => 'Zug Kandy → Ella';

  @override
  String get demoFlightHomeColombo => 'Rückflug ab Colombo';

  @override
  String get demoLionRock => 'Löwenfelsen';

  @override
  String get demoToothTemple => 'Zahntempel';

  @override
  String get demoTrainNote =>
      'Plätze 2. Klasse reservieren – rechte Seite für die Aussicht!';

  @override
  String get demoPreparation => 'Vorbereitung';

  @override
  String get demoPreparationItems =>
      'ETA-Visum beantragen|Impfungen checken|Mückenschutz|Rupien tauschen';

  @override
  String get demoRailwayTimetable => 'Sri Lanka Railways Fahrplan';

  @override
  String get demoRoughIdea => 'Grobe Idee';

  @override
  String get demoRoughIdeaText =>
      'Kulturdreieck → Hochland → Süden/Strand.\nZwischen Ella und Mirissa sind noch Tage frei – Yala-Safari?';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Speichern';

  @override
  String get discard => 'Verwerfen';

  @override
  String get keepEditing => 'Weiter bearbeiten';

  @override
  String get undo => 'Rückgängig';

  @override
  String get unsavedChangesTitle => 'Ungespeicherte Änderungen';

  @override
  String get unsavedChangesBody => 'Sollen die Änderungen gespeichert werden?';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get hintTimeline =>
      'Block lange drücken und ziehen, um ihn zu verschieben. Tag-Kopf lange drücken, um an diesem Tag etwas hinzuzufügen. Mit zwei Fingern zoomen.';

  @override
  String get hintMap =>
      'Lange auf die Karte drücken, um dort einen Ort, eine Unterkunft oder eine Aktivität anzulegen.';

  @override
  String get hintCanvas =>
      'Karten lange drücken und ziehen, um sie zu verschieben. Mit zwei Fingern zoomen.';

  @override
  String fixedApplied(String fix) {
    return 'Behoben: $fix';
  }

  @override
  String get notScheduledYet => 'Noch nicht eingeplant';

  @override
  String stepChosen(String title) {
    return '„$title“ gewählt';
  }

  @override
  String stepMarkedBooked(String title) {
    return '„$title“ als gebucht markiert';
  }

  @override
  String stepUnbooked(String title) {
    return '„$title“ nicht mehr gebucht';
  }

  @override
  String stepFixed(String title) {
    return '„$title“ fixiert';
  }

  @override
  String stepUnfixed(String title) {
    return '„$title“ nicht mehr fix';
  }

  @override
  String stepShiftedDays(String title, String sign, String days) {
    return '„$title“ $sign$days';
  }

  @override
  String stepDeleted(String title) {
    return '„$title“ gelöscht';
  }

  @override
  String deleteQuestion(String title) {
    return '„$title“ löschen?';
  }

  @override
  String get fixedAppointment => 'Fixer Termin';

  @override
  String belongsTo(String title) {
    return 'Gehört zu $title';
  }

  @override
  String get edit => 'Bearbeiten';

  @override
  String get chooseThisOption => 'Diese Option wählen';

  @override
  String get sectionAccommodations => 'Unterkünfte';

  @override
  String get sectionActivities => 'Aktivitäten';

  @override
  String get sectionLinks => 'Links';

  @override
  String get sectionAttachments => 'Tickets & Anhänge';

  @override
  String checklistProgress(int done, int total) {
    return '$done/$total erledigt';
  }

  @override
  String get add => 'Hinzufügen';

  @override
  String get transportHere => 'Transport hierher';

  @override
  String get transportOnward => 'Transport weiter';

  @override
  String get choose => 'Wählen';

  @override
  String get fixedChip => 'Fix';

  @override
  String get fixedTooltip => 'Fixe Termine bleiben beim Verschieben stehen';

  @override
  String get fixedNotMoved => 'Fixe Termine werden nicht verschoben';

  @override
  String get minusOneDay => '−1 Tag';

  @override
  String get plusOneDay => '+1 Tag';

  @override
  String checklistMoreDone(int count) {
    return '+ $count erledigt';
  }

  @override
  String get searchNotes => 'Notizen durchsuchen';

  @override
  String get notesEmpty =>
      'Sammle hier Ideen, Links, Screenshots und Checklisten.\nTippe auf + um etwas hinzuzufügen.';

  @override
  String get notesPinned => 'ANGEHEFTET';

  @override
  String get notesOthers => 'WEITERE';

  @override
  String get placeSearchFailed => 'Suche nicht möglich (offline?)';

  @override
  String get placeSearchHint => 'Ort, Stadt, Sehenswürdigkeit …';

  @override
  String get osmAttribution => 'Kartendaten © OpenStreetMap-Mitwirkende';

  @override
  String get timeOfDay => 'Uhrzeit';

  @override
  String get exactTime => 'Genaue Uhrzeit …';

  @override
  String get pickDay => 'Tag wählen';

  @override
  String get attachmentsTitle => 'Anhänge & Tickets';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get imageFromGallery => 'Bild aus Galerie';

  @override
  String get attachFileTooltip => 'Datei (PDF-Ticket …)';

  @override
  String get attachmentsEmpty =>
      'Noch nichts angehängt – z. B. Zugticket als PDF oder Screenshot der Buchung.';

  @override
  String get stepImageAttached => 'Bild angehängt';

  @override
  String get attachFileDialog => 'Datei anhängen';

  @override
  String stepFileAttached(String name) {
    return '„$name“ angehängt';
  }

  @override
  String removeQuestion(String name) {
    return '„$name“ entfernen?';
  }

  @override
  String stepFileRemoved(String name) {
    return '„$name“ entfernt';
  }

  @override
  String get newTrip => 'Neue Reise';

  @override
  String get editTrip => 'Reise bearbeiten';

  @override
  String get tripTitleLabel => 'Titel';

  @override
  String get tripTitleHint => 'z. B. Sri Lanka 2,5 Wochen';

  @override
  String get plannedDaysLabel => 'Geplante Dauer (Tage)';

  @override
  String get optional => 'optional';

  @override
  String get startDateOpen => 'Startdatum: noch offen';

  @override
  String startDateValue(String date) {
    return 'Start: $date';
  }

  @override
  String get removeDate => 'Datum entfernen';

  @override
  String get withoutDateHint => 'Ohne Datum wird mit „Tag 1, Tag 2 …“ geplant.';

  @override
  String get trashTitle => 'Papierkorb';

  @override
  String get trashEmptyAction => 'Leeren';

  @override
  String errorWith(String error) {
    return 'Fehler: $error';
  }

  @override
  String get trashIsEmpty =>
      'Der Papierkorb ist leer.\nGelöschte Reisen bleiben hier 30 Tage, dann werden sie endgültig entfernt.';

  @override
  String get trashEmptyQuestion => 'Papierkorb leeren?';

  @override
  String trashEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reisen werden',
      one: 'Eine Reise wird',
    );
    return '$_temp0 mit allen Orten, Notizen und Anhängen endgültig gelöscht.';
  }

  @override
  String get deleteForGood => 'Endgültig löschen';

  @override
  String trashPurgeHint(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Wird in $days Tagen endgültig gelöscht',
      one: 'Wird morgen endgültig gelöscht',
      zero: 'Wird beim nächsten Start endgültig gelöscht',
    );
    return '$_temp0';
  }

  @override
  String trashDeletedOn(String date) {
    return 'Gelöscht am $date';
  }

  @override
  String get restore => 'Wiederherstellen';

  @override
  String tripRestored(String title) {
    return '„$title“ wiederhergestellt';
  }

  @override
  String deleteTripForGoodQuestion(String title) {
    return '„$title“ endgültig löschen?';
  }

  @override
  String get deleteTripForGoodBody =>
      'Alle Orte, Notizen und Anhänge dieser Reise werden entfernt. Das lässt sich nicht rückgängig machen.';

  @override
  String get noBackupYet => 'Noch kein Backup';

  @override
  String lastBackup(String time) {
    return 'Letztes Backup: $time';
  }

  @override
  String get backupsTitle => 'Backups';

  @override
  String get backupNow => 'Jetzt sichern';

  @override
  String backupsExplanation(int keep, Object path) {
    return 'Tripboard sichert alle Reisen automatisch, wenn die App startet oder in den Hintergrund geht und das letzte Backup älter als einen Tag ist. Die letzten $keep Backups bleiben erhalten.\nSie liegen im App-Ordner$path und werden beim Deinstallieren gelöscht. Für eine dauerhafte Kopie ein Backup „Speichern unter …“ oder „Alle Reisen exportieren“ nutzen.';
  }

  @override
  String get noAutoBackups => 'Noch keine automatischen Backups.';

  @override
  String get saveAs => 'Speichern unter …';

  @override
  String get backupCreated => 'Backup erstellt';

  @override
  String backupFailed(String error) {
    return 'Backup fehlgeschlagen: $error';
  }

  @override
  String get restoreBackupQuestion => 'Backup wiederherstellen?';

  @override
  String restoreBackupBody(String time) {
    return 'Alle Reisen aus dem Backup vom $time werden auf diesen Stand zurückgesetzt oder wieder angelegt. Reisen, die nicht im Backup sind, bleiben unverändert. Der aktuelle Stand wird vorher als Backup gesichert.';
  }

  @override
  String tripsRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reisen wiederhergestellt',
      one: 'Eine Reise wiederhergestellt',
    );
    return '$_temp0';
  }

  @override
  String restoreFailed(String error) {
    return 'Wiederherstellen fehlgeschlagen: $error';
  }

  @override
  String get saveBackupDialog => 'Backup speichern';

  @override
  String get backupSaved => 'Backup gespeichert';

  @override
  String saveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get errorNotABackup => 'Kein Tripboard-Backup';

  @override
  String errorNewerData(int found, int supported) {
    return 'Die Daten stammen aus einer neueren App-Version (Format $found, unterstützt: $supported). Bitte Tripboard aktualisieren.';
  }

  @override
  String get myTrips => 'Meine Reisen';

  @override
  String get planWithClaude => 'Mit Claude planen …';

  @override
  String get exportAllTrips => 'Alle Reisen exportieren';

  @override
  String get importBackup => 'Backup importieren';

  @override
  String get backupsAndRestore => 'Backups & Wiederherstellen';

  @override
  String get loadDemoTrips => 'Beispielreisen laden';

  @override
  String get showHintsAgain => 'Tipps wieder anzeigen';

  @override
  String get hintsReset => 'Tipps werden wieder angezeigt';

  @override
  String get demoTripsCreated => 'Zwei Beispielreisen angelegt';

  @override
  String get chooseBackup => 'Backup wählen';

  @override
  String get noTripsInBackup => 'Keine Reisen im Backup';

  @override
  String tripsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reisen importiert',
      one: 'Eine Reise importiert',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get exportAsBackup => 'Als Backup exportieren';

  @override
  String get duplicate => 'Duplizieren';

  @override
  String get noPlacesYet => 'Noch keine Orte geplant';

  @override
  String get stepTripEdited => 'Reise bearbeitet';

  @override
  String get tripDeleted => 'Reise gelöscht';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get noTripsToExport => 'Keine Reisen zum Exportieren';

  @override
  String get allTripsFileName => 'tripboard-alle-reisen';

  @override
  String get saveAllTripsDialog => 'Alle Reisen speichern';

  @override
  String get allTripsExported => 'Alle Reisen exportiert';

  @override
  String get noTripYet => 'Noch keine Reise geplant';

  @override
  String get emptyTripsBody =>
      'Lege eine neue Reise an oder schau dir zuerst die Beispiele an (Interrail Frankreich/Spanien und Sri Lanka).';

  @override
  String get tripNotFound => 'Reise nicht gefunden';

  @override
  String undoWithLabel(String label) {
    return 'Rückgängig: $label';
  }

  @override
  String get exportBackup => 'Backup exportieren';

  @override
  String get layerOptions => 'Optionen';

  @override
  String get layerOptionsTooltip => 'Unterkunfts-Optionen zeigen';

  @override
  String get addSheetPlan => 'Plan';

  @override
  String get addSheetCollect => 'Sammeln';

  @override
  String get cardNote => 'Notiz';

  @override
  String get cardChecklist => 'Checkliste';

  @override
  String get cardLink => 'Link';

  @override
  String get cardImage => 'Bild';

  @override
  String get stepSharedSaved => 'Geteilte Inhalte gespeichert';

  @override
  String get saveToWhichTrip => 'In welche Reise speichern?';

  @override
  String get newTripEllipsis => 'Neue Reise …';

  @override
  String tripCreated(String title) {
    return 'Reise „$title“ angelegt';
  }

  @override
  String get exchangeSteps =>
      '1. Kopieren und in der Claude-App einfügen\n2. Deine Wünsche dazuschreiben und planen lassen\n3. Claudes Antwort kopieren (oder an Tripboard teilen) und hier übernehmen';

  @override
  String get copyTripForClaude => 'Reise für Claude kopieren';

  @override
  String get copyTripForClaudeSub => 'Anleitung + aktueller Plan';

  @override
  String get copyGuideOnly => 'Nur Anleitung kopieren';

  @override
  String get copyGuideOnlySub =>
      'Für eine neue Reise oder als Projekt-Anweisung in Claude';

  @override
  String get pastePlan => 'Plan aus Zwischenablage übernehmen';

  @override
  String get openPlanFile => 'Plan-Datei öffnen';

  @override
  String get copiedForClaude => 'Kopiert – jetzt in der Claude-App einfügen';

  @override
  String get clipboardEmpty => 'Zwischenablage ist leer';

  @override
  String get choosePlan => 'Plan wählen';

  @override
  String fileNotReadable(String error) {
    return 'Datei nicht lesbar: $error';
  }

  @override
  String get promptNewTrip => 'Neue Reise. Meine Wünsche: ';

  @override
  String get promptMyWishes => 'Meine Wünsche: ';

  @override
  String invalidPlan(String error) {
    return 'Kein gültiger Plan: $error';
  }

  @override
  String get planApplied => 'Plan übernommen';

  @override
  String get applyPlanTitle => 'Plan übernehmen';

  @override
  String get importTarget => 'Ziel';

  @override
  String newTripNamed(String title) {
    return 'Neue Reise „$title“';
  }

  @override
  String get planNoChanges => 'Der Plan enthält keine Änderungen.';

  @override
  String planItemsCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Einträge',
      one: '1 neuer Eintrag',
    );
    return '• $_temp0';
  }

  @override
  String planItemsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge geändert',
      one: '1 Eintrag geändert',
    );
    return '• $_temp0';
  }

  @override
  String planItemsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge gelöscht',
      one: '1 Eintrag gelöscht',
    );
    return '• $_temp0';
  }

  @override
  String planNotesCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Notizen',
      one: '1 neue Notiz',
    );
    return '• $_temp0';
  }

  @override
  String planNotesUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen geändert',
      one: '1 Notiz geändert',
    );
    return '• $_temp0';
  }

  @override
  String planNotesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen gelöscht',
      one: '1 Notiz gelöscht',
    );
    return '• $_temp0';
  }

  @override
  String get planFromOtherTrip =>
      'Der Plan stammt aus einer anderen Reise – alles wird neu angelegt.';

  @override
  String planTripChangedFields(String fields) {
    return '• Reisedaten ändern sich: $fields';
  }

  @override
  String get planFieldTitle => 'Titel';

  @override
  String get planFieldKind => 'Art';

  @override
  String get planFieldPlace => 'Ort';

  @override
  String get planFieldStatus => 'Status';

  @override
  String get planFieldFixed => 'Fix';

  @override
  String get planFieldTime => 'Zeit';

  @override
  String get planFieldNotes => 'Notizen';

  @override
  String get planFieldLinks => 'Links';

  @override
  String get planFieldRelation => 'Verknüpfung';

  @override
  String get planFieldMode => 'Verkehrsmittel';

  @override
  String get planFieldTicket => 'Ticketdaten';

  @override
  String get planFieldZone => 'Zeitzone';

  @override
  String get planFieldCost => 'Kosten';

  @override
  String get planFieldText => 'Text';

  @override
  String get planFieldUrl => 'Link';

  @override
  String get planFieldPinned => 'Angeheftet';

  @override
  String get planFieldChecklist => 'Checkliste';

  @override
  String get planFieldDates => 'Daten';

  @override
  String get planFieldCurrency => 'Währung';

  @override
  String get planFieldTravellers => 'Reisende';

  @override
  String get planFieldRates => 'Kurse';

  @override
  String get planEntryRemoved => 'Gelöscht';

  @override
  String planConflictsAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konflikte nach dem Import',
      one: '1 Konflikt nach dem Import',
      zero: 'Keine Konflikte nach dem Import',
    );
    return '$_temp0';
  }

  @override
  String planConflictsBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bisher $count',
      one: 'bisher 1',
      zero: 'bisher keiner',
    );
    return '$_temp0';
  }

  @override
  String geocodeNotFound(int missing, int total) {
    return '$missing von $total nicht gefunden';
  }

  @override
  String get geocodeNotFoundSub =>
      'Der Plan ist übernommen. Diese Einträge haben keine Koordinaten und fehlen auf der Karte; den Ort im Editor nachtragen.';

  @override
  String get clipboardPlanFound =>
      'Plan in der Zwischenablage gefunden. Plan übernehmen?';

  @override
  String findCoordinates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Koordinaten für $count Einträge suchen',
      one: 'Koordinaten für 1 Eintrag suchen',
    );
    return '$_temp0';
  }

  @override
  String get findCoordinatesSub => 'Über OpenStreetMap, braucht Internet';

  @override
  String planWarningsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Hinweise',
      one: '1 Hinweis',
    );
    return '$_temp0';
  }

  @override
  String get apply => 'Übernehmen';

  @override
  String get searchingCoordinates => 'Suche Koordinaten …';

  @override
  String get saving => 'Speichere …';

  @override
  String get stepPlanImported => 'Plan importiert';

  @override
  String get showAll => 'Alles zeigen';

  @override
  String withoutPlaceCount(int count) {
    return '$count ohne Ort';
  }

  @override
  String get addHere => 'Hier anlegen';

  @override
  String get itemsWithoutPlace => 'Diese Elemente haben noch keinen Ort';

  @override
  String get stepNoteCreated => 'Notiz angelegt';

  @override
  String stepCardCreated(String title) {
    return '„$title“ angelegt';
  }

  @override
  String get stepNoteChanged => 'Notiz geändert';

  @override
  String stepCardChanged(String title) {
    return '„$title“ geändert';
  }

  @override
  String get stepNoteDiscarded => 'Notiz verworfen';

  @override
  String get stepNoteDeleted => 'Notiz gelöscht';

  @override
  String get unpin => 'Lösen';

  @override
  String get pin => 'Anheften';

  @override
  String get addToPlan => 'In Plan übernehmen …';

  @override
  String get convertToNote => 'In Notiz umwandeln';

  @override
  String get convertToChecklist => 'In Checkliste umwandeln';

  @override
  String get titleHint => 'Titel';

  @override
  String get belongsToLabel => 'Gehört zu';

  @override
  String get nothingOption => '— nichts —';

  @override
  String get urlLabel => 'URL';

  @override
  String get loadPreview => 'Vorschau laden';

  @override
  String get open => 'Öffnen';

  @override
  String get previewFailed => 'Vorschau konnte nicht geladen werden';

  @override
  String get entryHint => 'Eintrag';

  @override
  String doneCount(int count) {
    return '$count erledigt';
  }

  @override
  String get deleteNoteQuestion => 'Notiz löschen?';

  @override
  String get addToPlanAs => 'Als … in den Plan übernehmen';

  @override
  String get pickedOnMap => 'Auf der Karte gewählt';

  @override
  String transportTo(String title) {
    return 'Nach $title';
  }

  @override
  String transportFrom(String title) {
    return 'Ab $title';
  }

  @override
  String newItemTitle(String kind) {
    return 'Neu: $kind';
  }

  @override
  String get titleHintStay => 'z. B. Kandy';

  @override
  String get titleHintTransport => 'z. B. Zug Kandy → Ella';

  @override
  String get titleHintAccommodation => 'z. B. Tree House Ella';

  @override
  String get titleHintActivity => 'z. B. Safari im Yala NP';

  @override
  String get statusLabel => 'Status';

  @override
  String get fixedSubtitle =>
      'Bewegt sich nicht, wenn davor etwas verschoben wird (z. B. gebuchte Tour, Rückflug)';

  @override
  String get inSchedule => 'Im Zeitplan';

  @override
  String get hasTimes => 'Hat Tage/Uhrzeiten';

  @override
  String get collectedOnly => 'Nur gesammelt – noch ohne Termin';

  @override
  String get notesLabel => 'Notizen';

  @override
  String get noTitle => '(ohne Titel)';

  @override
  String get belongsToPlace => 'Gehört zu Ort';

  @override
  String get movesWithPlace =>
      'Wird mitverschoben, wenn sich der Ort verschiebt.';

  @override
  String get transportMode => 'Verkehrsmittel';

  @override
  String get fromLabel => 'Von';

  @override
  String get toLabel => 'Nach';

  @override
  String get setPlaceOnMap => 'Ort auf der Karte festlegen';

  @override
  String get roughIsEnough => 'Grob reicht – die Stadt genügt';

  @override
  String get labelArrival => 'Ankunft';

  @override
  String get labelCheckIn => 'Check-in';

  @override
  String get labelDeparture => 'Abfahrt';

  @override
  String get labelStart => 'Beginn';

  @override
  String get labelLeave => 'Abreise';

  @override
  String get labelCheckOut => 'Check-out';

  @override
  String get labelEnd => 'Ende';

  @override
  String get daysExplanation =>
      'Tage zählen jeden angebrochenen Tag. Früh ankommen und spät abreisen = mehr Tage bei gleich vielen Nächten.';

  @override
  String get addLink => 'Link hinzufügen';

  @override
  String stepItemCreated(String title) {
    return '„$title“ angelegt';
  }

  @override
  String stepItemChanged(String title) {
    return '„$title“ geändert';
  }

  @override
  String othersMoved(int count, String mode) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Elemente',
      one: '1 weiteres Element',
    );
    return '$_temp0 verschoben ($mode)';
  }

  @override
  String stepMovedOnCanvas(String title) {
    return '„$title“ auf dem Canvas verschoben';
  }

  @override
  String get stepConnectionRemoved => 'Verbindung entfernt';

  @override
  String get stepConnectionCreated => 'Verbindung erstellt';

  @override
  String get connect => 'Verbinden';

  @override
  String get connectFirst => 'Verbinden: tippe auf das erste Element';

  @override
  String get connectSecond =>
      'Jetzt das zweite Element antippen (gleiches Paar nochmal = Verbindung lösen)';

  @override
  String get dragging => 'Ziehen …';

  @override
  String nightTitle(String from, String to) {
    return 'Nacht $from → $to';
  }

  @override
  String stepMoved(String title) {
    return '„$title“ verschoben';
  }

  @override
  String stepEndChanged(String title) {
    return '„$title“: Ende geändert';
  }

  @override
  String stepStartChanged(String title) {
    return '„$title“: Beginn geändert';
  }

  @override
  String othersMovedAlong(int count) {
    return '$count weitere mitverschoben';
  }

  @override
  String conflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konflikte',
      one: '1 Konflikt',
    );
    return '$_temp0';
  }

  @override
  String freeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage frei',
      one: '1 Tag frei',
    );
    return '$_temp0';
  }

  @override
  String noTransportBetween(String from, String to) {
    return 'Kein Transport von „$from“ nach „$to“';
  }

  @override
  String itemIsFixed(String title) {
    return '„$title“ ist fix und wird nicht verschoben';
  }

  @override
  String nightsShort(int count) {
    return '${count}N';
  }

  @override
  String get noAccommodationTonight => 'Noch keine Unterkunft für diese Nacht';

  @override
  String get chooseOption => 'Option wählen';

  @override
  String get newAccommodation => 'Neue Unterkunft';

  @override
  String noAccommodationOptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch keine Unterkunft – $count Optionen',
      one: 'Noch keine Unterkunft – 1 Option',
      zero: 'Noch keine Unterkunft für diese Nacht',
    );
    return '$_temp0';
  }

  @override
  String get shiftModeTooltip => 'Verschiebe-Modus';

  @override
  String get zoomOut => 'Verkleinern';

  @override
  String get zoomIn => 'Vergrößern';

  @override
  String get unscheduledLabel => 'Ohne Termin:';

  @override
  String get viewAgenda => 'Heute';

  @override
  String get agendaToday => 'Heute';

  @override
  String get agendaTomorrow => 'Morgen';

  @override
  String get agendaYesterday => 'Gestern';

  @override
  String get agendaJumpToToday => 'Springe zu heute';

  @override
  String get agendaWhere => 'Hier bist du';

  @override
  String get agendaNextTransport => 'Nächster Transport';

  @override
  String get agendaProgramme => 'Programm';

  @override
  String get agendaNothingPlanned => 'Für diesen Tag ist nichts geplant.';

  @override
  String agendaCheckIn(String time) {
    return 'Check-in $time';
  }

  @override
  String agendaCheckOut(String time) {
    return 'Check-out $time';
  }

  @override
  String agendaDeparts(String time) {
    return 'Abfahrt $time';
  }

  @override
  String agendaArrives(String time) {
    return 'Ankunft $time';
  }

  @override
  String get agendaNoBed => 'Für diese Nacht fehlt noch eine Unterkunft';

  @override
  String agendaOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Optionen',
      one: '1 Option',
    );
    return '$_temp0';
  }

  @override
  String agendaOpenFile(String name) {
    return '$name öffnen';
  }

  @override
  String get agendaNoStartDate =>
      'Ohne Startdatum zeigt die Agenda Reisetage. Lege eines unter ⋮ → Reise bearbeiten fest, um „Heute“ zu sehen.';

  @override
  String agendaStartsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die Reise beginnt in $count Tagen.',
      one: 'Die Reise beginnt morgen.',
    );
    return '$_temp0';
  }

  @override
  String get agendaEnded => 'Diese Reise ist vorbei.';

  @override
  String agendaOpenFailed(String name) {
    return '$name ließ sich nicht öffnen. Ist eine App für diesen Dateityp installiert?';
  }

  @override
  String get placesListEmpty => 'Die Reise hat noch keine Orte.';

  @override
  String get mapNoPlaces => 'Noch keine Orte mit Koordinaten.';

  @override
  String get mapNoCoordinates => 'Ohne Ort';

  @override
  String get mapOpenInMapsApp => 'In Karten-App öffnen';

  @override
  String get mapUnavailableTitle => 'Karte nicht verfügbar';

  @override
  String get mapUnavailableOffline =>
      'Keine Internetverbindung, und die Karte dieser Reise ist nicht offline gespeichert. Hier sind ihre Orte.';

  @override
  String get mapUnavailableFailed =>
      'Die Karte ließ sich nicht laden. Hier sind die Orte der Reise.';

  @override
  String get mapRetry => 'Erneut versuchen';

  @override
  String get mapOfflineLimited => 'Offline – Teile der Karte fehlen evtl.';

  @override
  String get mapOfflineSaved => 'Offline – gespeicherte Karte';

  @override
  String get mapPlaces => 'Orte';

  @override
  String get mapPlacesTitle => 'Orte dieser Reise';

  @override
  String get offlineMapTitle => 'Karte offline';

  @override
  String get offlineMapSave => 'Karte offline speichern';

  @override
  String get offlineMapSaveAgain => 'Erneut speichern';

  @override
  String get offlineMapExplain =>
      'Speichert die Karte rund um alle Orte der Reise – eine Übersicht der ganzen Route und Straßenebene rund um jeden Ort –, damit sie ohne Internet funktioniert.';

  @override
  String offlineMapEstimate(int tiles, String size) {
    return 'Etwa $tiles Kacheln, ca. $size.';
  }

  @override
  String offlineMapProgress(int percent, String size) {
    return '$percent % · $size geladen';
  }

  @override
  String get offlineMapProgressHint =>
      'Läuft weiter, wenn du die Karte verlässt. Ohne Verbindung wartet es, bis wieder Netz da ist.';

  @override
  String get offlineMapSaved => 'Offline gespeichert';

  @override
  String offlineMapSavedInfo(String date, String size) {
    return 'Gespeichert am $date · $size';
  }

  @override
  String get offlineMapIncomplete =>
      'Der letzte Download wurde nicht fertig. Erneut speichern oder löschen.';

  @override
  String get offlineMapOutdated =>
      'Einige Orte liegen außerhalb des gespeicherten Bereichs. Erneut speichern, um sie aufzunehmen.';

  @override
  String offlineMapFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get offlineMapNeedsConnection =>
      'Zum Speichern ist eine Internetverbindung nötig.';

  @override
  String get offlineMapDelete => 'Offline-Karte löschen';

  @override
  String get offlineMapDeleteConfirm => 'Offline-Karte dieser Reise löschen?';

  @override
  String get transportDetails => 'Ticketdaten';

  @override
  String get departureStationLabel => 'Abfahrt von (Bahnhof / Flughafen)';

  @override
  String get arrivalStationLabel => 'Ankunft in (Bahnhof / Flughafen)';

  @override
  String get transportNumberLabel => 'Zug- / Flugnummer';

  @override
  String get seatLabel => 'Sitzplatz / Gleis';

  @override
  String get bookingRefLabel => 'Buchungsnummer';

  @override
  String get copyBookingRef => 'Buchungsnummer kopieren';

  @override
  String get bookingRefCopied => 'Buchungsnummer kopiert';

  @override
  String get timeZoneLabel => 'Zeitzone';

  @override
  String get homeZoneLabel => 'Heimat-Zeitzone';

  @override
  String get homeZoneHint =>
      'Gilt für Orte und Zeiten ohne eigene Zone. Leer lassen, um ohne Zeitzonen zu planen.';

  @override
  String get zoneNone => 'Keine';

  @override
  String zoneNoneHome(String zone) {
    return 'Keine – Zone der Reise ($zone)';
  }

  @override
  String zoneAutomatic(String zone) {
    return 'Automatisch ($zone)';
  }

  @override
  String get zoneAutomaticNone => 'Automatisch (keine Zone)';

  @override
  String get departureZoneLabel => 'Zeitzone Abfahrt';

  @override
  String get arrivalZoneLabel => 'Zeitzone Ankunft';

  @override
  String get transportZoneHint =>
      'Automatisch nimmt die Zone des Orts, den man verlässt bzw. erreicht.';

  @override
  String get stayZoneHint =>
      'Zeiten dieses Orts, seiner Unterkünfte und Aktivitäten gelten in dieser Ortszeit.';

  @override
  String get pickTimeZone => 'Zeitzone wählen';

  @override
  String get searchTimeZone => 'Stadt, Zone oder UTC-Versatz suchen';

  @override
  String get zonesInTrip => 'In dieser Reise';

  @override
  String get allZones => 'Alle Zonen';

  @override
  String get noZoneMatches => 'Keine passende Zeitzone';

  @override
  String localTimeIn(String zone) {
    return 'Ortszeit $zone';
  }

  @override
  String realDuration(String duration) {
    return 'Dauer $duration';
  }

  @override
  String warnUnknownTimeZone(String entry, String field, String value) {
    return '„$entry“: $field: unbekannte Zeitzone „$value“ (erwartet z. B. „Asia/Colombo“) – ignoriert';
  }

  @override
  String warnUnknownTripTimeZone(String value) {
    return 'Reise: unbekannte Zeitzone „$value“ (erwartet z. B. „Europe/Berlin“) – ignoriert';
  }

  @override
  String get navigation => 'Navigation';

  @override
  String get noNavigationApp => 'Keine App für die Navigation gefunden.';

  @override
  String get myLocation => 'Mein Standort';

  @override
  String get locationServiceOff => 'Der Standort ist ausgeschaltet.';

  @override
  String get locationDenied => 'Tripboard darf den Standort nicht verwenden.';

  @override
  String get locationDeniedForever =>
      'Der Standortzugriff ist gesperrt. Erlaube ihn in den App-Einstellungen.';

  @override
  String get locationUnavailable =>
      'Der Standort konnte nicht ermittelt werden.';

  @override
  String get locationSettings => 'Einstellungen';

  @override
  String placeNoResults(String query) {
    return 'Keine Treffer für „$query“';
  }

  @override
  String get placeNoResultsHint =>
      'Schreibweise prüfen, die Stadt versuchen oder einen Kartenlink bzw. Koordinaten einfügen.';

  @override
  String get placeOfflineHint =>
      'Zuletzt verwendete Orte, Kartenlinks und Koordinaten gehen auch ohne Verbindung.';

  @override
  String get placeShortLinkOffline => 'Kurzlinks brauchen eine Verbindung';

  @override
  String get placeRecent => 'Zuletzt verwendet';

  @override
  String get placeUseCoordinates => 'Diese Koordinaten übernehmen';

  @override
  String get placeFromLink => 'Aus dem Link';

  @override
  String get placeLinkNoCoordinates => 'Der Link enthält keine Koordinaten';

  @override
  String get placePasteHint =>
      'Tipp: Google-Maps-, OpenStreetMap- oder geo:-Link oder Koordinaten wie 48.8584, 2.2945 einfügen.';

  @override
  String placeSaveWithoutCoordinates(String name) {
    return '„$name“ ohne Koordinaten speichern';
  }

  @override
  String get placeSaveWithoutCoordinatesHint =>
      'Erscheint nicht auf der Karte – die genaue Lage kannst du später setzen.';

  @override
  String get placeNoCoordinates => 'Ohne Koordinaten – nicht auf der Karte';

  @override
  String stepScheduled(String title, String day) {
    return '„$title“ eingeplant am $day';
  }

  @override
  String scheduleOnDay(String day) {
    return 'Einplanen am $day';
  }

  @override
  String get scheduleOnEllipsis => 'Einplanen am …';

  @override
  String get scheduleOtherDay => 'Oder an einem anderen Tag';

  @override
  String scheduleDefaultsHint(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'stay': 'Ankunft 14:00, zwei Nächte – danach anpassbar.',
      'accommodation': 'Check-in 15:00 bis zum Check-out am Ende des Orts.',
      'activity': '10:00–12:00 – danach anpassbar.',
      'other': 'Ab Ende des Startorts, sonst 10:00–13:00.',
    });
    return '$_temp0';
  }

  @override
  String get details => 'Details';

  @override
  String get timelineEmptyTitle => 'Noch keine Orte';

  @override
  String get timelineEmptyBody =>
      'Beginne mit dem ersten Ort deiner Reise – Unterkünfte, Transporte und Aktivitäten bauen darauf auf.';

  @override
  String get timelineEmptyAction => 'Ersten Ort anlegen';

  @override
  String get costSection => 'Kosten';

  @override
  String get costAmountLabel => 'Betrag';

  @override
  String get costCurrencyLabel => 'Währung';

  @override
  String get costCurrencyHintNone => 'Code, z. B. EUR';

  @override
  String get costTotal => 'Gesamt';

  @override
  String get costPerPerson => 'Pro Person';

  @override
  String get costPaid => 'Bezahlt';

  @override
  String get costOpen => 'Offen';

  @override
  String get costInvalidAmount => 'Kein gültiger Betrag';

  @override
  String get costInvalidCurrency => 'Code aus drei Buchstaben wie EUR';

  @override
  String costTravellersTotal(int count, String total) {
    return '$count Reisende: $total';
  }

  @override
  String costPerPersonOf(String amount) {
    return '$amount pro Person';
  }

  @override
  String costTimesPerPerson(int count, String amount) {
    return '$count × $amount pro Person';
  }

  @override
  String costApprox(String amount) {
    return '≈ $amount';
  }

  @override
  String get costHint =>
      'Schätzungen reichen – markiere es als bezahlt, sobald es das ist.';

  @override
  String get tripCurrencyLabel => 'Heimatwährung';

  @override
  String get tripCurrencyHint =>
      'Darin zeigt das Budget alle Kosten, z. B. EUR.';

  @override
  String get travellersLabel => 'Reisende';

  @override
  String stepMarkedPaid(String title) {
    return '„$title“ als bezahlt markiert';
  }

  @override
  String stepMarkedUnpaid(String title) {
    return '„$title“ als offen markiert';
  }

  @override
  String stepRateChanged(String currency) {
    return 'Wechselkurs $currency';
  }

  @override
  String get budget => 'Budget';

  @override
  String get budgetEmptyTitle => 'Noch keine Kosten';

  @override
  String get budgetEmptyBody =>
      'Trage Kosten im Editor ein – bei Orten, Transporten, Unterkünften oder Aktivitäten – oder lass Claude geschätzte Preise ergänzen.';

  @override
  String get budgetByLayer => 'Nach Ebene';

  @override
  String get budgetNotCounted => 'Optionen & Ideen (nicht eingerechnet)';

  @override
  String budgetMissingRate(String currency, String amount) {
    return 'Kein Wechselkurs für $currency – $amount nicht eingerechnet';
  }

  @override
  String get budgetEnterRate => 'Kurs eingeben';

  @override
  String get budgetRates => 'Wechselkurse';

  @override
  String get budgetRatesHint =>
      'Von dir eingetragen und mit der Reise gespeichert – so funktioniert das Budget auch offline.';

  @override
  String budgetRateValue(String home, String rate, String currency) {
    return '1 $home = $rate $currency';
  }

  @override
  String get budgetRateMissing => 'Kein Kurs';

  @override
  String get budgetAddRate => 'Kurs hinzufügen';

  @override
  String budgetRateDialogTitle(String currency) {
    return 'Wechselkurs für $currency';
  }

  @override
  String budgetRateDialogHint(String currency, String home) {
    return 'Wie viel $currency bekommt man für 1 $home?';
  }

  @override
  String get budgetRemoveRate => 'Kurs entfernen';

  @override
  String get budgetNoCurrency =>
      'Lege eine Heimatwährung fest, um Fremdwährungen umzurechnen.';

  @override
  String budgetCurrencyGuessed(String currency) {
    return 'Keine Heimatwährung festgelegt – angezeigt wird $currency, die am häufigsten verwendete.';
  }

  @override
  String budgetSettingsLine(String currency, int count) {
    return 'Heimatwährung: $currency · Reisende: $count';
  }

  @override
  String get budgetCurrencyNotSet => 'nicht festgelegt';

  @override
  String get budgetItems => 'Posten';

  @override
  String budgetPaidOf(String paid, String total) {
    return '$paid von $total bezahlt';
  }

  @override
  String warnInvalidCost(String entry, String value) {
    return '„$entry“: Kosten $value ohne gültigen Betrag – ignoriert';
  }

  @override
  String warnUnknownCurrency(String entry, String field, String value) {
    return '„$entry“: $field: unbekannte Währung „$value“ (erwartet ein Code wie „EUR“) – ignoriert';
  }

  @override
  String warnUnknownTripCurrency(String field, String value) {
    return 'Reise: $field: unbekannte Währung „$value“ (erwartet ein Code wie „EUR“) – ignoriert';
  }

  @override
  String warnInvalidRate(String field, String value) {
    return 'Reise: Wechselkurs für $field „$value“ ist keine positive Zahl – ignoriert';
  }

  @override
  String get a11yDayLater => '1 Tag später';

  @override
  String get a11yDayEarlier => '1 Tag früher';

  @override
  String get a11yConflict => 'Konflikt';

  @override
  String get a11ySelected => 'Ausgewählt';

  @override
  String get a11yHintAdd => 'Hinzufügen';

  @override
  String get a11yHintDetails => 'Details anzeigen';

  @override
  String get a11yHintAddOnDay => 'An diesem Tag etwas hinzufügen';

  @override
  String a11yMap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Karte mit $count Orten',
      one: 'Karte mit 1 Ort',
      zero: 'Karte, keine Orte',
    );
    return '$_temp0';
  }

  @override
  String get a11yPlacesList => 'Orte als Liste';

  @override
  String a11yColor(String name) {
    return 'Farbe: $name';
  }

  @override
  String get colorDefault => 'Standard';

  @override
  String get colorYellow => 'Gelb';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorGreen => 'Grün';

  @override
  String get colorBlue => 'Blau';

  @override
  String get colorPurple => 'Lila';

  @override
  String get colorPink => 'Rosa';

  @override
  String get colorBrown => 'Braun';

  @override
  String get colorTeal => 'Petrol';

  @override
  String get colorGrey => 'Grau';

  @override
  String get shareMenu => 'Teilen …';

  @override
  String get shareSheetTitle => 'Mit Mitreisenden teilen';

  @override
  String get shareSheetHint =>
      'Nur Geplantes und Gebuchtes; Optionen und Ideen bleiben privat.';

  @override
  String get shareAsText => 'Reiseplan als Text';

  @override
  String get shareAsTextSub => 'Tag für Tag, für Messenger und E-Mail';

  @override
  String get shareAsPdf => 'Reiseplan als PDF';

  @override
  String get shareAsPdfSub => 'Zum Drucken oder Verschicken';

  @override
  String get shareCalendar => 'Kalender (ICS)';

  @override
  String get shareCalendarSub => 'Geplante und gebuchte Elemente als Termine';

  @override
  String get shareCalendarNeedsDate => 'Fragt zuerst nach dem Startdatum';

  @override
  String get shareCopyText => 'Text kopieren';

  @override
  String get shareTextCopied => 'Reiseplan kopiert';

  @override
  String get shareNoStartDate =>
      'Ohne Startdatum zeigt der Reiseplan Reisetage (Tag 1, Tag 2 …).';

  @override
  String get shareStartDateTitle => 'Wann beginnt die Reise?';

  @override
  String get shareStartDateBody =>
      'Ein Kalender braucht echte Daten. Wähle das Datum von Tag 1; es wird in der Reise gespeichert.';

  @override
  String get sharePickDate => 'Datum wählen';

  @override
  String get stepStartDateSet => 'Startdatum gesetzt';

  @override
  String get shareNothingToExport =>
      'Noch nichts mit Termin geplant oder gebucht.';

  @override
  String shareFailed(String error) {
    return 'Teilen fehlgeschlagen: $error';
  }

  @override
  String shareSubject(String title) {
    return 'Reiseplan: $title';
  }

  @override
  String get shareRoute => 'Route';

  @override
  String get shareDayByDay => 'Tag für Tag';

  @override
  String get shareFreeDay => 'Nichts geplant';

  @override
  String shareNight(String title) {
    return 'Übernachtung: $title';
  }

  @override
  String get shareNoBed => 'Noch keine Unterkunft';

  @override
  String shareCheckIn(String title) {
    return 'Check-in: $title';
  }

  @override
  String shareCheckOut(String title) {
    return 'Check-out: $title';
  }

  @override
  String get shareBooked => 'gebucht';

  @override
  String shareNightsUntil(String nights, String day) {
    return '$nights, bis $day';
  }

  @override
  String shareStayLine(String place, String nights, String from, String to) {
    return '$place – $nights ($from – $to)';
  }

  @override
  String shareDuration(String duration) {
    return 'Dauer $duration';
  }

  @override
  String shareGeneratedBy(String date) {
    return 'Erstellt mit Tripboard am $date';
  }

  @override
  String sharePdfPage(String page, String pages) {
    return 'Seite $page von $pages';
  }

  @override
  String get reminders => 'Erinnerungen';

  @override
  String get remindersSwitch => 'An diese Reise erinnern';

  @override
  String get remindersSwitchHint =>
      'Benachrichtigungen vor Abfahrten, Check-in und Check-out';

  @override
  String get remindersNeedStartDate =>
      'Erinnerungen brauchen echte Daten. Lege das Datum von Tag 1 fest, damit sie geplant werden.';

  @override
  String get remindersSetStartDate => 'Startdatum festlegen';

  @override
  String get remindersNotificationsOff =>
      'Benachrichtigungen sind für Tripboard ausgeschaltet, Erinnerungen können nicht erscheinen.';

  @override
  String get remindersAllow => 'Erlauben';

  @override
  String get remindersInexact =>
      'Ohne die Berechtigung für Wecker und Erinnerungen können Benachrichtigungen verspätet kommen, bei weit entfernten Terminen auch um Stunden.';

  @override
  String get remindersAllowExact => 'Genaue Zeiten erlauben';

  @override
  String get remindersWhen => 'Wann';

  @override
  String remindersLead(String duration) {
    return '$duration vorher';
  }

  @override
  String get remindersFor => 'Wofür';

  @override
  String get remindersDepartures => 'Abfahrten';

  @override
  String get remindersCheckIn => 'Check-in';

  @override
  String get remindersCheckOut => 'Check-out';

  @override
  String get remindersUpcoming => 'Nächste Erinnerungen';

  @override
  String get remindersNone =>
      'Keine anstehenden Erinnerungen: Es steht keine geplante oder gebuchte Abfahrt, kein Check-in und kein Check-out bevor.';

  @override
  String remindersMore(int count) {
    return '+$count weitere';
  }

  @override
  String get remindersOff => 'Aus';

  @override
  String remindersFiresAt(String when) {
    return 'Benachrichtigung $when';
  }

  @override
  String reminderDepartureTitle(String time, String title) {
    return 'Abfahrt $time: $title';
  }

  @override
  String reminderCheckInTitle(String time, String title) {
    return 'Check-in $time: $title';
  }

  @override
  String reminderCheckOutTitle(String time, String title) {
    return 'Check-out $time: $title';
  }

  @override
  String reminderIn(String duration) {
    return 'in $duration';
  }

  @override
  String get packingList => 'Packliste';

  @override
  String get packingTemplates => 'Vorlagen';

  @override
  String get packingTemplateBasics => 'Basis';

  @override
  String get packingTemplateBeach => 'Strand';

  @override
  String get packingTemplateHiking => 'Wandern';

  @override
  String get packingTemplateCity => 'Stadt';

  @override
  String get packingTemplateBasicsItems =>
      'Reisepass / Ausweis|Geldbeutel & Karten|Handy-Ladekabel|Powerbank|Reiseadapter|Medikamente|Reiseapotheke|Zahnbürste & Kulturbeutel|Unterwäsche|Socken|T-Shirts|Hosen|Schlafsachen|Regenjacke|Kopfhörer|Kopien der Dokumente';

  @override
  String get packingTemplateBeachItems =>
      'Badesachen|Sonnencreme|Sonnenbrille|Sonnenhut|Strandtuch|Flip-Flops|After-Sun-Lotion|Wasserdichte Handyhülle|Schnorchelausrüstung|Buch';

  @override
  String get packingTemplateHikingItems =>
      'Wanderschuhe|Tagesrucksack|Trinkflasche|Regenjacke|Warme Schicht / Fleece|Wandersocken|Blasenpflaster|Stirnlampe|Offline-Karten|Snacks|Taschenmesser|Sonnencreme';

  @override
  String get packingTemplateCityItems =>
      'Bequeme Schuhe|Tagestasche|Offline-Karten|Fahrkarte für den Nahverkehr|Regenschirm|Schickes Outfit|Wiederverwendbare Trinkflasche|Museumstickets';

  @override
  String get packingCreate => 'Liste erstellen';

  @override
  String get packingAdd => 'Einträge hinzufügen';

  @override
  String packingEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get packingFromOtherTrip => 'Liste aus anderer Reise übernehmen';

  @override
  String get packingNoOtherLists =>
      'In anderen Reisen gibt es noch keine Checklisten.';

  @override
  String packingSource(String trip, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$trip · $_temp0';
  }

  @override
  String get packingAddFrom => 'Aus Vorlage oder Reise ergänzen …';

  @override
  String packingEntriesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge hinzugefügt',
      one: '1 Eintrag hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get packingNothingNew => 'Alle Einträge stehen schon auf der Liste';

  @override
  String stepEntryTicked(String entry) {
    return '„$entry“ abgehakt';
  }

  @override
  String stepEntryUnticked(String entry) {
    return '„$entry“ wieder offen';
  }

  @override
  String get entryMoveUp => 'Nach oben';

  @override
  String get entryMoveDown => 'Nach unten';

  @override
  String get entryDragHandle => 'Ziehen zum Sortieren';

  @override
  String get entryDelete => 'Eintrag löschen';

  @override
  String get search => 'Suchen';

  @override
  String get searchHint => 'Titel, Orte, Notizen … suchen';

  @override
  String get searchScopeTrip => 'Diese Reise';

  @override
  String get searchScopeAll => 'Alle Reisen';

  @override
  String get searchIntro =>
      'Durchsucht Titel, Orte, Notizen, Links, Ticketdaten, Checklisten und Anhänge deiner Reisen.';

  @override
  String searchNoResults(String query) {
    return 'Keine Treffer für „$query“';
  }

  @override
  String get searchNoResultsHint =>
      'Prüfe die Schreibweise oder versuche ein kürzeres Wort.';

  @override
  String get searchNoResultsTrip =>
      'Nichts in dieser Reise – in allen Reisen suchen?';

  @override
  String searchHitCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Treffer',
      one: '1 Treffer',
    );
    return '$_temp0';
  }

  @override
  String get searchClear => 'Suche leeren';

  @override
  String get searchFieldPlace => 'Ort';

  @override
  String get searchFieldText => 'Text';

  @override
  String get searchFieldAttachment => 'Anhang';

  @override
  String get searchFieldLinks => 'Link';

  @override
  String get searchOpenTrip => 'Reise öffnen';

  @override
  String conflictLodgingsOverlap(String item, String other, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nächte',
      one: '1 Nacht',
    );
    return '„$item“ und „$other“ sind beide für $_temp0 fest eingeplant';
  }

  @override
  String conflictActivityDuringTransport(String item, String transport) {
    return '„$item“ liegt in der Fahrzeit von „$transport“';
  }

  @override
  String conflictTransportsOverlap(String item, String other) {
    return '„$item“ fährt ab, bevor „$other“ ankommt';
  }

  @override
  String fixMakeOption(String title) {
    return '„$title“ zur Option machen';
  }

  @override
  String fixMoveBeforeTransport(String title) {
    return 'Vor „$title“ legen';
  }

  @override
  String fixMoveAfterTransport(String title) {
    return 'Nach „$title“ legen';
  }

  @override
  String noFixFixed(String title) {
    return 'Keine automatische Lösung: „$title“ ist fix. Von Hand ändern oder „Fix“ lösen.';
  }

  @override
  String get noFixBothBooked =>
      'Keine automatische Lösung: Beide sind gebucht. Eines stornieren oder verschieben.';

  @override
  String get noFixManual =>
      'Keine automatische Lösung. Elemente öffnen und Zeiten anpassen.';

  @override
  String openItemTitled(String title) {
    return '„$title“ öffnen';
  }

  @override
  String get showConflicts => 'Konflikte anzeigen';

  @override
  String get noConflicts => 'Keine Konflikte';

  @override
  String demotedToOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count andere Unterkünfte sind jetzt Optionen',
      one: '1 andere Unterkunft ist jetzt Option',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get filesTitle => 'Dateien';

  @override
  String get filesTooltip => 'Dateien & Tickets';

  @override
  String get filesEmpty =>
      'Noch keine Dateien. Lege hier Tickets, Buchungen, Fotos oder ganze Ordner ab – sie bleiben auf dem Gerät, sind im Backup enthalten und lassen sich mit Orten, Transporten und Notizen verknüpfen.';

  @override
  String get filesFolderEmpty => 'Dieser Ordner ist leer.';

  @override
  String get filesAdd => 'Hinzufügen';

  @override
  String get filesPickFiles => 'Dateien wählen';

  @override
  String get filesPickFilesHint =>
      'Mehrere auf einmal: erste lange drücken, dann weitere antippen';

  @override
  String get filesPickImages => 'Fotos aus der Galerie';

  @override
  String get filesImportFolder => 'Ordner importieren';

  @override
  String get filesNewFolder => 'Neuer Ordner';

  @override
  String get filesFolderName => 'Ordnername';

  @override
  String get filesRename => 'Umbenennen';

  @override
  String get filesMove => 'In Ordner verschieben';

  @override
  String get filesLink => 'Mit Elementen verknüpfen';

  @override
  String get filesShare => 'Teilen';

  @override
  String get filesOpen => 'Öffnen';

  @override
  String get filesSelect => 'Auswählen';

  @override
  String get filesUnlink => 'Verknüpfung lösen';

  @override
  String get filesUntitledNote => 'Notiz';

  @override
  String get filesChooseFromWorkspace => 'Aus den Dateien der Reise';

  @override
  String get filesNoneToPick => 'Diese Reise hat noch keine weiteren Dateien.';

  @override
  String get showInFiles => 'In Dateien zeigen';

  @override
  String get filesFolderUnreadable =>
      'Tripboard kann diesen Ordner nicht lesen. Nimm stattdessen „Dateien wählen“ und markiere dort alle Dateien.';

  @override
  String filesFolderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
      zero: 'Leer',
    );
    return '$_temp0';
  }

  @override
  String filesSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String filesFolderPartly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien waren nicht lesbar.',
      one: '1 Datei war nicht lesbar.',
    );
    return '$_temp0';
  }

  @override
  String stepFilesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien hinzugefügt',
      one: '1 Datei hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String stepFolderCreated(String name) {
    return 'Ordner „$name“ angelegt';
  }

  @override
  String stepFolderRenamed(String name) {
    return 'Ordner in „$name“ umbenannt';
  }

  @override
  String stepFolderDeleted(String name) {
    return 'Ordner „$name“ gelöscht';
  }

  @override
  String stepFilesMoved(String folder) {
    return 'Nach „$folder“ verschoben';
  }

  @override
  String stepFileRenamed(String name) {
    return 'In „$name“ umbenannt';
  }

  @override
  String stepFilesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien gelöscht',
      one: '1 Datei gelöscht',
    );
    return '$_temp0';
  }

  @override
  String stepFileLinksChanged(String name) {
    return 'Verknüpfungen von „$name“ geändert';
  }

  @override
  String stepFileUnlinked(String name) {
    return '„$name“ gelöst – bleibt in den Dateien der Reise';
  }

  @override
  String deleteFolderQuestion(String name) {
    return 'Ordner „$name“ löschen?';
  }

  @override
  String deleteFolderBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die $count Dateien darin werden mitgelöscht.',
      one: 'Die Datei darin wird mitgelöscht.',
    );
    return '$_temp0';
  }

  @override
  String deleteFilesQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien löschen?',
      one: '1 Datei löschen?',
    );
    return '$_temp0';
  }

  @override
  String get deleteFilesBody =>
      'Verknüpfte Orte, Transporte und Notizen verlieren die Datei ebenfalls.';

  @override
  String get timelineVertical => 'Senkrecht anzeigen';

  @override
  String get timelineHorizontal => 'Waagerecht anzeigen';
}
