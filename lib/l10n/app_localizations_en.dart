// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tripboard';

  @override
  String get kindStay => 'Place';

  @override
  String get kindTransport => 'Transport';

  @override
  String get kindAccommodation => 'Accommodation';

  @override
  String get kindActivity => 'Activity';

  @override
  String get statusIdea => 'Idea';

  @override
  String get statusOption => 'Option';

  @override
  String get statusPlanned => 'Planned';

  @override
  String get statusBooked => 'Booked';

  @override
  String get modeTrain => 'Train';

  @override
  String get modeBus => 'Bus';

  @override
  String get modePlane => 'Flight';

  @override
  String get modeFerry => 'Ferry';

  @override
  String get modeCar => 'Car';

  @override
  String get modeTaxi => 'Taxi/Tuk-tuk';

  @override
  String get modeWalk => 'On foot';

  @override
  String get modeOther => 'Other';

  @override
  String get shiftFollowing => 'Move everything after';

  @override
  String get shiftPush => 'Only push when needed';

  @override
  String get shiftSingle => 'Only this item';

  @override
  String get shiftFollowingShort => 'Everything after';

  @override
  String get shiftPushShort => 'Use buffer';

  @override
  String get shiftSingleShort => 'Only this';

  @override
  String get dayPartMorning => 'Morning';

  @override
  String get dayPartMidday => 'Midday';

  @override
  String get dayPartAfternoon => 'Afternoon';

  @override
  String get dayPartEvening => 'Evening';

  @override
  String get dayPartNight => 'Night';

  @override
  String get viewCanvas => 'Canvas';

  @override
  String get viewNotes => 'Notes';

  @override
  String get viewTimeline => 'Schedule';

  @override
  String get viewMap => 'Map';

  @override
  String dayNumber(int n) {
    return 'Day $n';
  }

  @override
  String dayWithNumber(String date, int n) {
    return '$date (day $n)';
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
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
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
    return 'Layer $n: $kind';
  }

  @override
  String conflictStaysOverlap(String item, String duration, String other) {
    return '“$item” starts $duration before “$other” ends';
  }

  @override
  String conflictLodgingOutsideStay(String item, String other) {
    return '“$item” doesn\'t fit the days in $other';
  }

  @override
  String conflictActivityOutsideStay(String item, String other) {
    return '“$item” is outside the stay in $other';
  }

  @override
  String conflictStayEndsAfterDeparture(String stay, String transport) {
    return '“$stay” ends after “$transport” departs';
  }

  @override
  String conflictDaysBeforeDeparture(int days, String stay, String transport) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 without a place between “$stay” and the departure of “$transport”';
  }

  @override
  String conflictStayStartsBeforeArrival(String stay, String transport) {
    return '“$stay” starts before “$transport” arrives';
  }

  @override
  String conflictDaysAfterArrival(int days, String transport, String stay) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 without a place between the arrival of “$transport” and “$stay”';
  }

  @override
  String fixPushLater(String title) {
    return 'Push “$title” back';
  }

  @override
  String fixFitNightsToStay(String title) {
    return 'Fit nights to $title';
  }

  @override
  String fixMoveIntoStay(String title) {
    return 'Move into $title';
  }

  @override
  String fixShortenToDeparture(String title) {
    return 'Shorten “$title” to the departure';
  }

  @override
  String fixExtendToDeparture(String title) {
    return 'Extend “$title” to the departure';
  }

  @override
  String fixStartLaterAtArrival(String title) {
    return 'Start “$title” only on arrival';
  }

  @override
  String fixStartEarlierAtArrival(String title) {
    return 'Start “$title” on arrival';
  }

  @override
  String warnRemoveUnknown(String value) {
    return 'remove: “$value” does not exist – ignored';
  }

  @override
  String warnDuplicateRef(String value) {
    return 'ref “$value” appears more than once – only the first entry counts';
  }

  @override
  String warnRefNotFound(String entry, String field, String value) {
    return '“$entry”: $field “$value” not found – link removed';
  }

  @override
  String warnUnknownKind(String entry, String value) {
    return '“$entry”: unknown kind “$value” – skipped';
  }

  @override
  String warnMissingKind(String entry) {
    return '“$entry”: “kind” missing – skipped';
  }

  @override
  String warnMissingTitle(String entry) {
    return 'Entry without a title (ref $entry) – skipped';
  }

  @override
  String warnUnknownStatus(String entry, String value) {
    return '“$entry”: unknown status “$value” – ignored';
  }

  @override
  String warnUnknownMode(String entry, String value) {
    return '“$entry”: unknown mode “$value” – using “other”';
  }

  @override
  String warnSelfReference(String entry, String field) {
    return '“$entry”: $field points to itself – removed';
  }

  @override
  String warnStartOrEndOnly(String entry) {
    return '“$entry”: only start or end given – stays unscheduled';
  }

  @override
  String warnEndBeforeStart(String entry) {
    return '“$entry”: end is before start – time not applied';
  }

  @override
  String warnUnsupportedNoteType(String entry, String value) {
    return '“$entry”: note type “$value” is not supported – skipped';
  }

  @override
  String warnImageTypeFixed(String entry) {
    return '“$entry”: image notes can\'t change their type – type ignored';
  }

  @override
  String warnEmptyNote(String entry) {
    return 'Empty note (ref $entry) – skipped';
  }

  @override
  String warnNotAnInteger(String field, String value) {
    return 'Trip: $field “$value” is not a whole number – ignored';
  }

  @override
  String warnInvalidStartDate(String value) {
    return 'Trip: startDate “$value” is not a date (YYYY-MM-DD) – ignored';
  }

  @override
  String warnDateNeedsStartDate(String entry, String field) {
    return '“$entry”: $field: a date needs the trip\'s start date (trip.startDate) – ignored';
  }

  @override
  String warnInvalidMoment(
    String entry,
    String field,
    String value,
    String example,
  ) {
    return '“$entry”: $field: “$value” not understood (expected $example) – ignored';
  }

  @override
  String planErrorInvalidJson(String detail) {
    return 'No valid JSON found ($detail)';
  }

  @override
  String get planErrorNotAnObject => 'No plan found (JSON object expected)';

  @override
  String planErrorUnknownFormat(String detail, String expected) {
    return 'Unknown format “$detail” (expected: $expected)';
  }

  @override
  String get planErrorNotAPlan =>
      'Not a Tripboard plan: “items” or “trip” missing';

  @override
  String planErrorTooNew(String detail, int supported) {
    return 'Plan version $detail is newer than this app (supports $supported)';
  }

  @override
  String get importedTripTitle => 'Imported trip';

  @override
  String get demoInterrailTitle => 'Interrail France & Spain';

  @override
  String get demoAvignonNotes =>
      'Might fit into the free days between Lyon and Barcelona';

  @override
  String get demoSagradaFamilia => 'Sagrada Família (booked)';

  @override
  String get demoPaellaCourse => 'Paella cooking class';

  @override
  String get demoFlightHomeValencia => 'Flight home Valencia → Home';

  @override
  String get demoPassTitle => 'Interrail Pass';

  @override
  String get demoPassText =>
      'Global Pass: 7 travel days within 1 month.\nReservations needed for TGV & Euromed!';

  @override
  String get demoPackingList => 'Packing list';

  @override
  String get demoPackingItems =>
      'Passport|Interrail app offline|Adapter|Swimwear|Power bank';

  @override
  String get demoReservationsLink => 'Interrail reservations';

  @override
  String get demoFreeDaysTitle => 'Free days 7–8';

  @override
  String get demoFreeDaysText => 'Ideas: Avignon, Montpellier or Carcassonne?';

  @override
  String get demoSriLankaTitle => 'Sri Lanka 2.5 weeks';

  @override
  String get demoYalaName => 'Yala National Park';

  @override
  String get demoYalaNotes =>
      'Safari early in the morning – between Ella and Mirissa';

  @override
  String get demoFlightOut => 'Flight out';

  @override
  String get demoTrainKandyElla => 'Train Kandy → Ella';

  @override
  String get demoFlightHomeColombo => 'Flight home from Colombo';

  @override
  String get demoLionRock => 'Lion Rock';

  @override
  String get demoToothTemple => 'Temple of the Tooth';

  @override
  String get demoTrainNote =>
      'Reserve 2nd class seats – right side for the view!';

  @override
  String get demoPreparation => 'Preparation';

  @override
  String get demoPreparationItems =>
      'Apply for ETA visa|Check vaccinations|Mosquito repellent|Exchange rupees';

  @override
  String get demoRailwayTimetable => 'Sri Lanka Railways timetable';

  @override
  String get demoRoughIdea => 'Rough idea';

  @override
  String get demoRoughIdeaText =>
      'Cultural triangle → highlands → south/beach.\nThere are free days between Ella and Mirissa – Yala safari?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Save';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get undo => 'Undo';

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get unsavedChangesBody => 'Do you want to save your changes?';

  @override
  String get gotIt => 'Got it';

  @override
  String get hintTimeline =>
      'Long-press a block and drag to move it. Long-press a day header to add something on that day. Pinch with two fingers to zoom.';

  @override
  String get hintMap =>
      'Long-press the map to add a place, an accommodation or an activity there.';

  @override
  String get hintCanvas =>
      'Long-press cards and drag to move them. Pinch with two fingers to zoom.';

  @override
  String fixedApplied(String fix) {
    return 'Fixed: $fix';
  }

  @override
  String get notScheduledYet => 'Not scheduled yet';

  @override
  String stepChosen(String title) {
    return '“$title” chosen';
  }

  @override
  String stepMarkedBooked(String title) {
    return '“$title” marked as booked';
  }

  @override
  String stepUnbooked(String title) {
    return '“$title” no longer booked';
  }

  @override
  String stepFixed(String title) {
    return '“$title” fixed';
  }

  @override
  String stepUnfixed(String title) {
    return '“$title” no longer fixed';
  }

  @override
  String stepShiftedDays(String title, String sign, String days) {
    return '“$title” $sign$days';
  }

  @override
  String stepDeleted(String title) {
    return '“$title” deleted';
  }

  @override
  String deleteQuestion(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get fixedAppointment => 'Fixed appointment';

  @override
  String belongsTo(String title) {
    return 'Belongs to $title';
  }

  @override
  String get edit => 'Edit';

  @override
  String get chooseThisOption => 'Choose this option';

  @override
  String get sectionAccommodations => 'Accommodations';

  @override
  String get sectionActivities => 'Activities';

  @override
  String get sectionLinks => 'Links';

  @override
  String get sectionAttachments => 'Tickets & attachments';

  @override
  String checklistProgress(int done, int total) {
    return '$done/$total done';
  }

  @override
  String get add => 'Add';

  @override
  String get transportHere => 'Transport here';

  @override
  String get transportOnward => 'Onward transport';

  @override
  String get choose => 'Choose';

  @override
  String get fixedChip => 'Fixed';

  @override
  String get fixedTooltip => 'Fixed items stay put when things move';

  @override
  String get fixedNotMoved => 'Fixed items are not moved';

  @override
  String get minusOneDay => '−1 day';

  @override
  String get plusOneDay => '+1 day';

  @override
  String checklistMoreDone(int count) {
    return '+ $count done';
  }

  @override
  String get searchNotes => 'Search notes';

  @override
  String get notesEmpty =>
      'Collect ideas, links, screenshots and checklists here.\nTap + to add something.';

  @override
  String get notesPinned => 'PINNED';

  @override
  String get notesOthers => 'OTHERS';

  @override
  String get placeSearchFailed => 'Search not possible (offline?)';

  @override
  String get placeSearchHint => 'Place, city, sight …';

  @override
  String get osmAttribution => 'Map data © OpenStreetMap contributors';

  @override
  String get timeOfDay => 'Time';

  @override
  String get exactTime => 'Exact time …';

  @override
  String get pickDay => 'Choose day';

  @override
  String get attachmentsTitle => 'Attachments & tickets';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get imageFromGallery => 'Image from gallery';

  @override
  String get attachFileTooltip => 'File (PDF ticket …)';

  @override
  String get attachmentsEmpty =>
      'Nothing attached yet – e.g. a train ticket as PDF or a screenshot of the booking.';

  @override
  String get stepImageAttached => 'Image attached';

  @override
  String get attachFileDialog => 'Attach file';

  @override
  String stepFileAttached(String name) {
    return '“$name” attached';
  }

  @override
  String removeQuestion(String name) {
    return 'Remove “$name”?';
  }

  @override
  String stepFileRemoved(String name) {
    return '“$name” removed';
  }

  @override
  String get newTrip => 'New trip';

  @override
  String get editTrip => 'Edit trip';

  @override
  String get tripTitleLabel => 'Title';

  @override
  String get tripTitleHint => 'e.g. Sri Lanka 2.5 weeks';

  @override
  String get plannedDaysLabel => 'Planned length (days)';

  @override
  String get optional => 'optional';

  @override
  String get startDateOpen => 'Start date: not set yet';

  @override
  String startDateValue(String date) {
    return 'Start: $date';
  }

  @override
  String get removeDate => 'Remove date';

  @override
  String get withoutDateHint =>
      'Without a date you plan with “Day 1, Day 2 …”.';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmptyAction => 'Empty';

  @override
  String errorWith(String error) {
    return 'Error: $error';
  }

  @override
  String get trashIsEmpty =>
      'The trash is empty.\nDeleted trips stay here for 30 days, then they are removed for good.';

  @override
  String get trashEmptyQuestion => 'Empty trash?';

  @override
  String trashEmptyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips will be deleted for good',
      one: 'One trip will be deleted for good',
    );
    return '$_temp0 with all places, notes and attachments.';
  }

  @override
  String get deleteForGood => 'Delete for good';

  @override
  String trashPurgeHint(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Will be deleted for good in $days days',
      one: 'Will be deleted for good tomorrow',
      zero: 'Will be deleted for good on next start',
    );
    return '$_temp0';
  }

  @override
  String trashDeletedOn(String date) {
    return 'Deleted on $date';
  }

  @override
  String get restore => 'Restore';

  @override
  String tripRestored(String title) {
    return '“$title” restored';
  }

  @override
  String deleteTripForGoodQuestion(String title) {
    return 'Delete “$title” for good?';
  }

  @override
  String get deleteTripForGoodBody =>
      'All places, notes and attachments of this trip will be removed. This cannot be undone.';

  @override
  String get noBackupYet => 'No backup yet';

  @override
  String lastBackup(String time) {
    return 'Last backup: $time';
  }

  @override
  String get backupsTitle => 'Backups';

  @override
  String get backupNow => 'Back up now';

  @override
  String backupsExplanation(int keep, Object path) {
    return 'Tripboard backs up all trips automatically when the app starts or goes to the background and the last backup is older than a day. The last $keep backups are kept.\nThey are stored in the app folder$path and are deleted when the app is uninstalled. For a permanent copy use “Save as …” on a backup or “Export all trips”.';
  }

  @override
  String get noAutoBackups => 'No automatic backups yet.';

  @override
  String get saveAs => 'Save as …';

  @override
  String get backupCreated => 'Backup created';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get restoreBackupQuestion => 'Restore backup?';

  @override
  String restoreBackupBody(String time) {
    return 'All trips from the backup of $time are reset to that state or created again. Trips that are not in the backup stay unchanged. The current state is backed up first.';
  }

  @override
  String tripsRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips restored',
      one: 'One trip restored',
    );
    return '$_temp0';
  }

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get saveBackupDialog => 'Save backup';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String saveFailed(String error) {
    return 'Saving failed: $error';
  }

  @override
  String get errorNotABackup => 'Not a Tripboard backup';

  @override
  String errorNewerData(int found, int supported) {
    return 'The data is from a newer app version (format $found, supported: $supported). Please update Tripboard.';
  }

  @override
  String get myTrips => 'My trips';

  @override
  String get planWithClaude => 'Plan with Claude …';

  @override
  String get exportAllTrips => 'Export all trips';

  @override
  String get importBackup => 'Import backup';

  @override
  String get backupsAndRestore => 'Backups & restore';

  @override
  String get loadDemoTrips => 'Load example trips';

  @override
  String get showHintsAgain => 'Show tips again';

  @override
  String get hintsReset => 'Tips will be shown again';

  @override
  String get demoTripsCreated => 'Two example trips created';

  @override
  String get chooseBackup => 'Choose backup';

  @override
  String get noTripsInBackup => 'No trips in the backup';

  @override
  String tripsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips imported',
      one: 'One trip imported',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get exportAsBackup => 'Export as backup';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get noPlacesYet => 'No places planned yet';

  @override
  String get stepTripEdited => 'Trip edited';

  @override
  String get tripDeleted => 'Trip deleted';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get noTripsToExport => 'No trips to export';

  @override
  String get allTripsFileName => 'tripboard-all-trips';

  @override
  String get saveAllTripsDialog => 'Save all trips';

  @override
  String get allTripsExported => 'All trips exported';

  @override
  String get noTripYet => 'No trip planned yet';

  @override
  String get emptyTripsBody =>
      'Create a new trip or have a look at the examples first (Interrail France/Spain and Sri Lanka).';

  @override
  String get tripNotFound => 'Trip not found';

  @override
  String undoWithLabel(String label) {
    return 'Undo: $label';
  }

  @override
  String get exportBackup => 'Export backup';

  @override
  String get layerOptions => 'Options';

  @override
  String get layerOptionsTooltip => 'Show accommodation options';

  @override
  String get addSheetPlan => 'Plan';

  @override
  String get addSheetCollect => 'Collect';

  @override
  String get cardNote => 'Note';

  @override
  String get cardChecklist => 'Checklist';

  @override
  String get cardLink => 'Link';

  @override
  String get cardImage => 'Image';

  @override
  String get stepSharedSaved => 'Shared content saved';

  @override
  String get saveToWhichTrip => 'Save to which trip?';

  @override
  String get newTripEllipsis => 'New trip …';

  @override
  String tripCreated(String title) {
    return 'Trip “$title” created';
  }

  @override
  String get exchangeSteps =>
      '1. Copy and paste into the Claude app\n2. Add your wishes and let it plan\n3. Copy Claude\'s answer (or share it to Tripboard) and apply it here';

  @override
  String get copyTripForClaude => 'Copy trip for Claude';

  @override
  String get copyTripForClaudeSub => 'Guide + current plan';

  @override
  String get copyGuideOnly => 'Copy guide only';

  @override
  String get copyGuideOnlySub =>
      'For a new trip or as project instructions in Claude';

  @override
  String get pastePlan => 'Apply plan from clipboard';

  @override
  String get openPlanFile => 'Open plan file';

  @override
  String get copiedForClaude => 'Copied – now paste it into the Claude app';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get choosePlan => 'Choose plan';

  @override
  String fileNotReadable(String error) {
    return 'File not readable: $error';
  }

  @override
  String get promptNewTrip => 'New trip. My wishes: ';

  @override
  String get promptMyWishes => 'My wishes: ';

  @override
  String invalidPlan(String error) {
    return 'Not a valid plan: $error';
  }

  @override
  String get planApplied => 'Plan applied';

  @override
  String get applyPlanTitle => 'Apply plan';

  @override
  String get importTarget => 'Target';

  @override
  String newTripNamed(String title) {
    return 'New trip “$title”';
  }

  @override
  String get planNoChanges => 'The plan contains no changes.';

  @override
  String get planTripChanged => '• Trip details (title/start/length) change';

  @override
  String planItemsCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new entries',
      one: '1 new entry',
    );
    return '• $_temp0';
  }

  @override
  String planItemsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries changed',
      one: '1 entry changed',
    );
    return '• $_temp0';
  }

  @override
  String planItemsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries deleted',
      one: '1 entry deleted',
    );
    return '• $_temp0';
  }

  @override
  String planNotesCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new notes',
      one: '1 new note',
    );
    return '• $_temp0';
  }

  @override
  String planNotesUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes changed',
      one: '1 note changed',
    );
    return '• $_temp0';
  }

  @override
  String planNotesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes deleted',
      one: '1 note deleted',
    );
    return '• $_temp0';
  }

  @override
  String get planFromOtherTrip =>
      'The plan comes from another trip – everything will be created anew.';

  @override
  String findCoordinates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Find coordinates for $count entries',
      one: 'Find coordinates for 1 entry',
    );
    return '$_temp0';
  }

  @override
  String get findCoordinatesSub => 'Via OpenStreetMap, needs internet';

  @override
  String planWarningsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String get apply => 'Apply';

  @override
  String get searchingCoordinates => 'Searching coordinates …';

  @override
  String get saving => 'Saving …';

  @override
  String get stepPlanImported => 'Plan imported';

  @override
  String get showAll => 'Show all';

  @override
  String withoutPlaceCount(int count) {
    return '$count without a place';
  }

  @override
  String get addHere => 'Add here';

  @override
  String get itemsWithoutPlace => 'These items don\'t have a place yet';

  @override
  String get stepNoteCreated => 'Note created';

  @override
  String stepCardCreated(String title) {
    return '“$title” created';
  }

  @override
  String get stepNoteChanged => 'Note changed';

  @override
  String stepCardChanged(String title) {
    return '“$title” changed';
  }

  @override
  String get stepNoteDiscarded => 'Note discarded';

  @override
  String get stepNoteDeleted => 'Note deleted';

  @override
  String get unpin => 'Unpin';

  @override
  String get pin => 'Pin';

  @override
  String get addToPlan => 'Add to plan …';

  @override
  String get convertToNote => 'Convert to note';

  @override
  String get convertToChecklist => 'Convert to checklist';

  @override
  String get titleHint => 'Title';

  @override
  String get belongsToLabel => 'Belongs to';

  @override
  String get nothingOption => '— nothing —';

  @override
  String get urlLabel => 'URL';

  @override
  String get loadPreview => 'Load preview';

  @override
  String get open => 'Open';

  @override
  String get previewFailed => 'Preview could not be loaded';

  @override
  String get entryHint => 'Entry';

  @override
  String doneCount(int count) {
    return '$count done';
  }

  @override
  String get deleteNoteQuestion => 'Delete note?';

  @override
  String get addToPlanAs => 'Add to the plan as …';

  @override
  String get pickedOnMap => 'Picked on the map';

  @override
  String transportTo(String title) {
    return 'To $title';
  }

  @override
  String transportFrom(String title) {
    return 'From $title';
  }

  @override
  String newItemTitle(String kind) {
    return 'New: $kind';
  }

  @override
  String get titleHintStay => 'e.g. Kandy';

  @override
  String get titleHintTransport => 'e.g. Train Kandy → Ella';

  @override
  String get titleHintAccommodation => 'e.g. Tree House Ella';

  @override
  String get titleHintActivity => 'e.g. Safari in Yala NP';

  @override
  String get statusLabel => 'Status';

  @override
  String get fixedSubtitle =>
      'Doesn\'t move when something before it is moved (e.g. booked tour, flight home)';

  @override
  String get inSchedule => 'In the schedule';

  @override
  String get hasTimes => 'Has days/times';

  @override
  String get collectedOnly => 'Only collected – no date yet';

  @override
  String get notesLabel => 'Notes';

  @override
  String get noTitle => '(no title)';

  @override
  String get belongsToPlace => 'Belongs to place';

  @override
  String get movesWithPlace => 'Moves along when the place moves.';

  @override
  String get transportMode => 'Mode of transport';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get setPlaceOnMap => 'Set place on the map';

  @override
  String get roughIsEnough => 'Rough is fine – the city is enough';

  @override
  String get labelArrival => 'Arrival';

  @override
  String get labelCheckIn => 'Check-in';

  @override
  String get labelDeparture => 'Departure';

  @override
  String get labelStart => 'Start';

  @override
  String get labelLeave => 'Departure';

  @override
  String get labelCheckOut => 'Check-out';

  @override
  String get labelEnd => 'End';

  @override
  String get daysExplanation =>
      'Days count every started day. Arriving early and leaving late = more days for the same number of nights.';

  @override
  String get addLink => 'Add link';

  @override
  String stepItemCreated(String title) {
    return '“$title” created';
  }

  @override
  String stepItemChanged(String title) {
    return '“$title” changed';
  }

  @override
  String othersMoved(int count, String mode) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more items moved',
      one: '1 more item moved',
    );
    return '$_temp0 ($mode)';
  }

  @override
  String stepMovedOnCanvas(String title) {
    return '“$title” moved on the canvas';
  }

  @override
  String get stepConnectionRemoved => 'Connection removed';

  @override
  String get stepConnectionCreated => 'Connection created';

  @override
  String get connect => 'Connect';

  @override
  String get connectFirst => 'Connect: tap the first item';

  @override
  String get connectSecond =>
      'Now tap the second item (same pair again = remove the connection)';

  @override
  String get dragging => 'Dragging …';

  @override
  String nightTitle(String from, String to) {
    return 'Night $from → $to';
  }

  @override
  String stepMoved(String title) {
    return '“$title” moved';
  }

  @override
  String stepEndChanged(String title) {
    return '“$title”: end changed';
  }

  @override
  String stepStartChanged(String title) {
    return '“$title”: start changed';
  }

  @override
  String othersMovedAlong(int count) {
    return '$count more moved along';
  }

  @override
  String conflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflicts',
      one: '1 conflict',
    );
    return '$_temp0';
  }

  @override
  String freeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days free',
      one: '1 day free',
    );
    return '$_temp0';
  }

  @override
  String noTransportBetween(String from, String to) {
    return 'No transport from “$from” to “$to”';
  }

  @override
  String itemIsFixed(String title) {
    return '“$title” is fixed and won\'t be moved';
  }

  @override
  String nightsShort(int count) {
    return '${count}N';
  }

  @override
  String get noAccommodationTonight => 'No accommodation for this night yet';

  @override
  String get chooseOption => 'Choose an option';

  @override
  String get newAccommodation => 'New accommodation';

  @override
  String noAccommodationOptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No accommodation yet – $count options',
      one: 'No accommodation yet – 1 option',
      zero: 'No accommodation for this night yet',
    );
    return '$_temp0';
  }

  @override
  String get shiftModeTooltip => 'Shift mode';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get unscheduledLabel => 'Unscheduled:';

  @override
  String get viewAgenda => 'Today';

  @override
  String get agendaToday => 'Today';

  @override
  String get agendaTomorrow => 'Tomorrow';

  @override
  String get agendaYesterday => 'Yesterday';

  @override
  String get agendaJumpToToday => 'Jump to today';

  @override
  String get agendaWhere => 'Where you are';

  @override
  String get agendaNextTransport => 'Next transport';

  @override
  String get agendaProgramme => 'Schedule';

  @override
  String get agendaNothingPlanned => 'Nothing planned for this day.';

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
    return 'Departs $time';
  }

  @override
  String agendaArrives(String time) {
    return 'Arrives $time';
  }

  @override
  String get agendaNoBed => 'No accommodation for this night yet';

  @override
  String agendaOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return '$_temp0';
  }

  @override
  String agendaOpenFile(String name) {
    return 'Open $name';
  }

  @override
  String get agendaNoStartDate =>
      'Without a start date the agenda shows trip days. Set one under ⋮ → Edit trip to see today.';

  @override
  String agendaStartsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The trip starts in $count days.',
      one: 'The trip starts tomorrow.',
    );
    return '$_temp0';
  }

  @override
  String get agendaEnded => 'This trip is over.';

  @override
  String agendaOpenFailed(String name) {
    return 'Couldn\'t open $name. Is an app for this file type installed?';
  }

  @override
  String get placesListEmpty => 'This trip has no places yet.';

  @override
  String get mapNoPlaces => 'No places with coordinates yet.';

  @override
  String get mapNoCoordinates => 'No location';

  @override
  String get mapOpenInMapsApp => 'Open in maps app';

  @override
  String get mapUnavailableTitle => 'Map not available';

  @override
  String get mapUnavailableOffline =>
      'No internet connection, and this trip\'s map isn\'t saved offline. Here are its places.';

  @override
  String get mapUnavailableFailed =>
      'The map couldn\'t be loaded. Here are the trip\'s places.';

  @override
  String get mapRetry => 'Try again';

  @override
  String get mapOfflineLimited => 'Offline – parts of the map may be missing.';

  @override
  String get mapOfflineSaved => 'Offline – showing the saved map';

  @override
  String get mapPlaces => 'Places';

  @override
  String get mapPlacesTitle => 'Places of this trip';

  @override
  String get offlineMapTitle => 'Offline map';

  @override
  String get offlineMapSave => 'Save map offline';

  @override
  String get offlineMapSaveAgain => 'Save again';

  @override
  String get offlineMapExplain =>
      'Saves the map around all places of the trip – an overview of the whole route and street level around every stay – so it works without internet.';

  @override
  String offlineMapEstimate(int tiles, String size) {
    return 'About $tiles tiles, roughly $size.';
  }

  @override
  String offlineMapProgress(int percent, String size) {
    return '$percent % · $size downloaded';
  }

  @override
  String get offlineMapProgressHint =>
      'Keeps running when you leave the map. Without a connection it waits until the network is back.';

  @override
  String get offlineMapSaved => 'Saved offline';

  @override
  String offlineMapSavedInfo(String date, String size) {
    return 'Saved $date · $size';
  }

  @override
  String get offlineMapIncomplete =>
      'The last download didn\'t finish. Save again or delete it.';

  @override
  String get offlineMapOutdated =>
      'Some places lie outside the saved area. Save again to include them.';

  @override
  String offlineMapFailed(String error) {
    return 'Saving failed: $error';
  }

  @override
  String get offlineMapNeedsConnection =>
      'Saving needs an internet connection.';

  @override
  String get offlineMapDelete => 'Delete offline map';

  @override
  String get offlineMapDeleteConfirm => 'Delete the offline map of this trip?';

  @override
  String get transportDetails => 'Ticket details';

  @override
  String get departureStationLabel => 'Departure station / airport';

  @override
  String get arrivalStationLabel => 'Arrival station / airport';

  @override
  String get transportNumberLabel => 'Train / flight no.';

  @override
  String get seatLabel => 'Seat / platform';

  @override
  String get bookingRefLabel => 'Booking reference';

  @override
  String get copyBookingRef => 'Copy booking reference';

  @override
  String get bookingRefCopied => 'Booking reference copied';

  @override
  String get timeZoneLabel => 'Time zone';

  @override
  String get homeZoneLabel => 'Home time zone';

  @override
  String get homeZoneHint =>
      'Applies to places and times without a zone of their own. Leave empty to plan without time zones.';

  @override
  String get zoneNone => 'None';

  @override
  String zoneNoneHome(String zone) {
    return 'None – trip\'s zone ($zone)';
  }

  @override
  String zoneAutomatic(String zone) {
    return 'Automatic ($zone)';
  }

  @override
  String get zoneAutomaticNone => 'Automatic (no zone)';

  @override
  String get departureZoneLabel => 'Departure time zone';

  @override
  String get arrivalZoneLabel => 'Arrival time zone';

  @override
  String get transportZoneHint =>
      'Automatic uses the zone of the place you leave or reach.';

  @override
  String get stayZoneHint =>
      'Times of this place, its accommodation and activities are local times there.';

  @override
  String get pickTimeZone => 'Choose time zone';

  @override
  String get searchTimeZone => 'Search city, zone or UTC offset';

  @override
  String get zonesInTrip => 'Used in this trip';

  @override
  String get allZones => 'All zones';

  @override
  String get noZoneMatches => 'No matching time zone';

  @override
  String localTimeIn(String zone) {
    return 'Local time $zone';
  }

  @override
  String realDuration(String duration) {
    return 'Duration $duration';
  }

  @override
  String warnUnknownTimeZone(String entry, String field, String value) {
    return '“$entry”: $field: unknown time zone “$value” (expected e.g. “Asia/Colombo”) – ignored';
  }

  @override
  String warnUnknownTripTimeZone(String value) {
    return 'Trip: unknown time zone “$value” (expected e.g. “Europe/Berlin”) – ignored';
  }

  @override
  String get navigation => 'Navigation';

  @override
  String get noNavigationApp => 'No app found for navigation.';

  @override
  String get myLocation => 'My location';

  @override
  String get locationServiceOff => 'Location is turned off.';

  @override
  String get locationDenied => 'Tripboard isn\'t allowed to use your location.';

  @override
  String get locationDeniedForever =>
      'Location access is blocked. Allow it in the app settings.';

  @override
  String get locationUnavailable => 'Your location couldn\'t be determined.';

  @override
  String get locationSettings => 'Settings';

  @override
  String placeNoResults(String query) {
    return 'No places found for “$query”';
  }

  @override
  String get placeNoResultsHint =>
      'Check the spelling, try the city, or paste a map link or coordinates.';

  @override
  String get placeOfflineHint =>
      'Recently used places, map links and coordinates work without a connection.';

  @override
  String get placeShortLinkOffline => 'Short links need a connection';

  @override
  String get placeRecent => 'Recently used';

  @override
  String get placeUseCoordinates => 'Use these coordinates';

  @override
  String get placeFromLink => 'From the link';

  @override
  String get placeLinkNoCoordinates => 'This link has no coordinates';

  @override
  String get placePasteHint =>
      'Tip: paste a Google Maps, OpenStreetMap or geo: link, or coordinates like 48.8584, 2.2945.';

  @override
  String placeSaveWithoutCoordinates(String name) {
    return 'Save “$name” without coordinates';
  }

  @override
  String get placeSaveWithoutCoordinatesHint =>
      'Not shown on the map – you can set the spot later.';

  @override
  String get placeNoCoordinates => 'No coordinates – not on the map';
}
