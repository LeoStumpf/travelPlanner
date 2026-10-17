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
  String get planTripChanged => '• Reisedaten (Titel/Start/Länge) ändern sich';

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
}
