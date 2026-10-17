// Localisation glue: `context.l10n` plus the wording of language-neutral
// domain values (enums, conflicts, plan warnings, days) via the ARB strings
// in lib/l10n.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../data/backup.dart';
import '../../data/doc_migrations.dart';
import '../../domain/analysis.dart';
import '../../domain/demo.dart';
import '../../domain/models.dart';
import '../../domain/packing.dart';
import '../../domain/plan_exchange.dart';
import '../../domain/scheduler.dart';
import '../../domain/search.dart';
import '../../domain/time.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

export '../../l10n/app_localizations.dart';

/// Languages the app ships; the first one is the fallback for any other
/// device language.
const appLocales = [Locale('en'), Locale('de')];

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension DomainL10n on AppLocalizations {
  String kind(ItemKind k) => switch (k) {
        ItemKind.stay => kindStay,
        ItemKind.transport => kindTransport,
        ItemKind.accommodation => kindAccommodation,
        ItemKind.activity => kindActivity,
      };

  /// "Ebene 2: Transport".
  String layer(ItemKind k) => layerLabel(k.layer, kind(k));

  String cardType(CardType t) => switch (t) {
        CardType.note => cardNote,
        CardType.checklist => cardChecklist,
        CardType.link => cardLink,
        CardType.image => cardImage,
      };

  /// Label of the field a search hit was found in.
  String searchField(SearchField f) => switch (f) {
        SearchField.title => planFieldTitle,
        SearchField.place => searchFieldPlace,
        SearchField.notes => notesLabel,
        SearchField.link => searchFieldLinks,
        SearchField.departureStation => departureStationLabel,
        SearchField.arrivalStation => arrivalStationLabel,
        SearchField.transportNumber => transportNumberLabel,
        SearchField.seat => seatLabel,
        SearchField.bookingRef => bookingRefLabel,
        SearchField.text => searchFieldText,
        SearchField.checklistEntry => cardChecklist,
        SearchField.attachment => searchFieldAttachment,
      };

  String status(ItemStatus s) => switch (s) {
        ItemStatus.idea => statusIdea,
        ItemStatus.option => statusOption,
        ItemStatus.planned => statusPlanned,
        ItemStatus.booked => statusBooked,
      };

  String mode(TransportMode m) => switch (m) {
        TransportMode.train => modeTrain,
        TransportMode.bus => modeBus,
        TransportMode.plane => modePlane,
        TransportMode.ferry => modeFerry,
        TransportMode.car => modeCar,
        TransportMode.taxi => modeTaxi,
        TransportMode.walk => modeWalk,
        TransportMode.other => modeOther,
      };

  String shiftMode(ShiftMode m) => switch (m) {
        ShiftMode.following => shiftFollowing,
        ShiftMode.push => shiftPush,
        ShiftMode.single => shiftSingle,
      };

  String shiftModeShort(ShiftMode m) => switch (m) {
        ShiftMode.following => shiftFollowingShort,
        ShiftMode.push => shiftPushShort,
        ShiftMode.single => shiftSingleShort,
      };

  String dayPart(DayPart p) => switch (p) {
        DayPart.morning => dayPartMorning,
        DayPart.midday => dayPartMidday,
        DayPart.afternoon => dayPartAfternoon,
        DayPart.evening => dayPartEvening,
        DayPart.night => dayPartNight,
      };

  String packingTemplate(PackingTemplate t) => switch (t) {
        PackingTemplate.basics => packingTemplateBasics,
        PackingTemplate.beach => packingTemplateBeach,
        PackingTemplate.hiking => packingTemplateHiking,
        PackingTemplate.city => packingTemplateCity,
      };

  /// The entries of template [t] in the active language.
  List<String> packingTemplateEntries(PackingTemplate t) => switch (t) {
        PackingTemplate.basics => packingTemplateBasicsItems,
        PackingTemplate.beach => packingTemplateBeachItems,
        PackingTemplate.hiking => packingTemplateHikingItems,
        PackingTemplate.city => packingTemplateCityItems,
      }
          .split('|');

  String view(TripView v) => switch (v) {
        TripView.canvas => viewCanvas,
        TripView.notes => viewNotes,
        TripView.timeline => viewTimeline,
        TripView.map => viewMap,
        TripView.agenda => viewAgenda,
      };

  /// "Day 3" without a start date, "Wed, Mar 12" / "Mi., 12. März" with one.
  String day(DateTime? tripStart, int day, {bool withDayNumber = false}) {
    if (tripStart == null) return dayNumber(day + 1);
    final s = DateFormat.MMMEd(localeName).format(dateOfDay(tripStart, day));
    return withDayNumber ? dayWithNumber(s, day + 1) : s;
  }

  /// "Today" / "Tomorrow" / "Yesterday" relative to trip day [today], else
  /// as [day].
  String relativeDay(DateTime? tripStart, int day, int? today) => switch (today == null ? null : day - today) {
        0 => agendaToday,
        1 => agendaTomorrow,
        -1 => agendaYesterday,
        _ => this.day(tripStart, day),
      };

  /// Day and clock time of a trip minute.
  String moment(DateTime? tripStart, int minute) => dayAndTime(day(tripStart, dayOf(minute)), formatClock(minute));

  /// A full calendar date, e.g. "Mar 12, 2027" / "12. März 2027".
  String date(DateTime d) => DateFormat.yMMMd(localeName).format(d);

  /// A numeric date with time, e.g. "17.10.2026 14:03" for backups.
  String dateTime(DateTime d) => DateFormat.yMd(localeName).add_Hm().format(d);

  /// [amount] in [currency] for this locale ("1.234,50 €", "LKR 12,000");
  /// without a currency just the number with two decimals.
  String money(double amount, String? currency) => currency == null
      ? NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: 2).format(amount)
      : NumberFormat.simpleCurrency(locale: localeName, name: currency).format(amount);

  /// An exchange rate with as many decimals as it needs (up to 6).
  String rate(double r) => (NumberFormat.decimalPattern(localeName)..maximumFractionDigits = 6).format(r);

  String days(int n) => daysCount(n);
  String nights(int n) => nightsCount(n);

  /// "2 days 3h", "5h"; minutes are only shown with [withMinutes].
  String duration(int minutes, {bool withMinutes = false}) {
    final d = minutes ~/ minutesPerDay;
    final h = (minutes % minutesPerDay) ~/ 60;
    final m = minutes % 60;
    final parts = [
      if (d > 0) daysCount(d),
      if (h > 0 || (d == 0 && (!withMinutes || m == 0))) hoursShort(h),
      if (withMinutes && m > 0) minutesShort(m),
    ];
    return parts.join(' ');
  }

  String conflict(Conflict c) => switch (c.type) {
        ConflictType.staysOverlap => conflictStaysOverlap(c.itemTitle, duration(c.amount), c.otherTitle),
        ConflictType.lodgingOutsideStay => conflictLodgingOutsideStay(c.itemTitle, c.otherTitle),
        ConflictType.activityOutsideStay => conflictActivityOutsideStay(c.itemTitle, c.otherTitle),
        ConflictType.stayEndsAfterDeparture => conflictStayEndsAfterDeparture(c.otherTitle, c.itemTitle),
        ConflictType.daysBeforeDeparture => conflictDaysBeforeDeparture(c.amount, c.otherTitle, c.itemTitle),
        ConflictType.stayStartsBeforeArrival => conflictStayStartsBeforeArrival(c.otherTitle, c.itemTitle),
        ConflictType.daysAfterArrival => conflictDaysAfterArrival(c.amount, c.itemTitle, c.otherTitle),
        ConflictType.lodgingsOverlap => conflictLodgingsOverlap(c.itemTitle, c.otherTitle, c.amount),
        ConflictType.activityDuringTransport => conflictActivityDuringTransport(c.itemTitle, c.otherTitle),
        ConflictType.transportsOverlap => conflictTransportsOverlap(c.itemTitle, c.otherTitle),
      };

  /// Why [c] has no one-tap fix and what to do instead.
  String conflictNoFix(Conflict c) => switch (c.noFix) {
        NoFixReason.fixed => noFixFixed(c.noFixSubject),
        NoFixReason.bothBooked => noFixBothBooked,
        NoFixReason.manual => noFixManual,
      };

  String conflictFix(ConflictFix f) => switch (f.type) {
        ConflictFixType.pushLater => fixPushLater(f.subject),
        ConflictFixType.fitNightsToStay => fixFitNightsToStay(f.subject),
        ConflictFixType.moveIntoStay => fixMoveIntoStay(f.subject),
        ConflictFixType.shortenToDeparture => fixShortenToDeparture(f.subject),
        ConflictFixType.extendToDeparture => fixExtendToDeparture(f.subject),
        ConflictFixType.startLaterAtArrival => fixStartLaterAtArrival(f.subject),
        ConflictFixType.startEarlierAtArrival => fixStartEarlierAtArrival(f.subject),
        ConflictFixType.makeOption => fixMakeOption(f.subject),
        ConflictFixType.moveBeforeTransport => fixMoveBeforeTransport(f.subject),
        ConflictFixType.moveAfterTransport => fixMoveAfterTransport(f.subject),
      };

  String planField(PlanField f) => switch (f) {
        PlanField.title => planFieldTitle,
        PlanField.kind => planFieldKind,
        PlanField.place => planFieldPlace,
        PlanField.status => planFieldStatus,
        PlanField.fixed => planFieldFixed,
        PlanField.time => planFieldTime,
        PlanField.notes => planFieldNotes,
        PlanField.links => planFieldLinks,
        PlanField.relation => planFieldRelation,
        PlanField.mode => planFieldMode,
        PlanField.ticket => planFieldTicket,
        PlanField.zone => planFieldZone,
        PlanField.cost => planFieldCost,
        PlanField.text => planFieldText,
        PlanField.url => planFieldUrl,
        PlanField.pinned => planFieldPinned,
        PlanField.checklist => planFieldChecklist,
        PlanField.dates => planFieldDates,
        PlanField.currency => planFieldCurrency,
        PlanField.travellers => planFieldTravellers,
        PlanField.rates => planFieldRates,
      };

  String planWarning(PlanWarning w) {
    final e = w.entry ?? '?', f = w.field ?? '', v = w.value ?? '';
    return switch (w.type) {
      PlanWarningType.removeUnknown => warnRemoveUnknown(v),
      PlanWarningType.duplicateRef => warnDuplicateRef(v),
      PlanWarningType.refNotFound => warnRefNotFound(e, f, v),
      PlanWarningType.unknownKind => warnUnknownKind(e, v),
      PlanWarningType.missingKind => warnMissingKind(e),
      PlanWarningType.missingTitle => warnMissingTitle(e),
      PlanWarningType.unknownStatus => warnUnknownStatus(e, v),
      PlanWarningType.unknownMode => warnUnknownMode(e, v),
      PlanWarningType.selfReference => warnSelfReference(e, f),
      PlanWarningType.startOrEndOnly => warnStartOrEndOnly(e),
      PlanWarningType.endBeforeStart => warnEndBeforeStart(e),
      PlanWarningType.unsupportedNoteType => warnUnsupportedNoteType(e, v),
      PlanWarningType.imageTypeFixed => warnImageTypeFixed(e),
      PlanWarningType.emptyNote => warnEmptyNote(e),
      PlanWarningType.notAnInteger => warnNotAnInteger(f, v),
      PlanWarningType.invalidStartDate => warnInvalidStartDate(v),
      PlanWarningType.dateNeedsStartDate => warnDateNeedsStartDate(e, f),
      PlanWarningType.invalidMoment => warnInvalidMoment(e, f, v, '{"day": 1, "time": "14:00"}'),
      PlanWarningType.unknownTimeZone => w.entry == null ? warnUnknownTripTimeZone(v) : warnUnknownTimeZone(e, f, v),
      PlanWarningType.invalidCost => warnInvalidCost(e, v),
      PlanWarningType.unknownCurrency => w.entry == null ? warnUnknownTripCurrency(f, v) : warnUnknownCurrency(e, f, v),
      PlanWarningType.invalidRate => warnInvalidRate(f, v),
    };
  }

  /// Why a text is not a plan. Other format errors keep their own message.
  String planError(FormatException e) {
    if (e is! PlanFormatException) return e.message;
    final d = e.detail ?? '–';
    return switch (e.type) {
      PlanErrorType.invalidJson => planErrorInvalidJson(d),
      PlanErrorType.notAnObject => planErrorNotAnObject,
      PlanErrorType.unknownFormat => planErrorUnknownFormat(d, planFormat),
      PlanErrorType.notAPlan => planErrorNotAPlan,
      PlanErrorType.tooNew => planErrorTooNew(d, planFormatVersion),
    };
  }

  /// An error for a snackbar: known ones in words, others as they are.
  String error(Object e) => switch (e) {
        NotABackupException() => errorNotABackup,
        NewerDataException(:final found, :final supported) => errorNewerData(found, supported),
        PlanFormatException() => planError(e),
        _ => '$e',
      };

  /// The demo trips' texts in this language.
  DemoTexts get demoTexts => DemoTexts(
        interrailTitle: demoInterrailTitle,
        avignonNotes: demoAvignonNotes,
        sagradaFamilia: demoSagradaFamilia,
        paellaCourse: demoPaellaCourse,
        flightHomeValencia: demoFlightHomeValencia,
        passTitle: demoPassTitle,
        passText: demoPassText,
        packingList: demoPackingList,
        packingItems: demoPackingItems.split('|'),
        reservationsLink: demoReservationsLink,
        freeDaysTitle: demoFreeDaysTitle,
        freeDaysText: demoFreeDaysText,
        sriLankaTitle: demoSriLankaTitle,
        yalaName: demoYalaName,
        yalaNotes: demoYalaNotes,
        flightOut: demoFlightOut,
        trainKandyElla: demoTrainKandyElla,
        flightHomeColombo: demoFlightHomeColombo,
        lionRock: demoLionRock,
        toothTemple: demoToothTemple,
        trainNote: demoTrainNote,
        preparation: demoPreparation,
        preparationItems: demoPreparationItems.split('|'),
        railwayTimetable: demoRailwayTimetable,
        roughIdea: demoRoughIdea,
        roughIdeaText: demoRoughIdeaText,
      );
}

/// "512 KB", "12.3 MB" / "12,3 MB" – file and download sizes.
String formatBytes(int bytes, [String? locale]) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)} KB'
    : '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1).format(bytes / 1024 / 1024)} MB';
