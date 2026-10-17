import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tripboard'**
  String get appTitle;

  /// No description provided for @kindStay.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get kindStay;

  /// No description provided for @kindTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get kindTransport;

  /// No description provided for @kindAccommodation.
  ///
  /// In en, this message translates to:
  /// **'Accommodation'**
  String get kindAccommodation;

  /// No description provided for @kindActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get kindActivity;

  /// No description provided for @statusIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get statusIdea;

  /// No description provided for @statusOption.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get statusOption;

  /// No description provided for @statusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statusPlanned;

  /// No description provided for @statusBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get statusBooked;

  /// No description provided for @modeTrain.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get modeTrain;

  /// No description provided for @modeBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get modeBus;

  /// No description provided for @modePlane.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get modePlane;

  /// No description provided for @modeFerry.
  ///
  /// In en, this message translates to:
  /// **'Ferry'**
  String get modeFerry;

  /// No description provided for @modeCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get modeCar;

  /// No description provided for @modeTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi/Tuk-tuk'**
  String get modeTaxi;

  /// No description provided for @modeWalk.
  ///
  /// In en, this message translates to:
  /// **'On foot'**
  String get modeWalk;

  /// No description provided for @modeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get modeOther;

  /// No description provided for @shiftFollowing.
  ///
  /// In en, this message translates to:
  /// **'Move everything after'**
  String get shiftFollowing;

  /// No description provided for @shiftPush.
  ///
  /// In en, this message translates to:
  /// **'Only push when needed'**
  String get shiftPush;

  /// No description provided for @shiftSingle.
  ///
  /// In en, this message translates to:
  /// **'Only this item'**
  String get shiftSingle;

  /// No description provided for @shiftFollowingShort.
  ///
  /// In en, this message translates to:
  /// **'Everything after'**
  String get shiftFollowingShort;

  /// No description provided for @shiftPushShort.
  ///
  /// In en, this message translates to:
  /// **'Use buffer'**
  String get shiftPushShort;

  /// No description provided for @shiftSingleShort.
  ///
  /// In en, this message translates to:
  /// **'Only this'**
  String get shiftSingleShort;

  /// No description provided for @dayPartMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get dayPartMorning;

  /// No description provided for @dayPartMidday.
  ///
  /// In en, this message translates to:
  /// **'Midday'**
  String get dayPartMidday;

  /// No description provided for @dayPartAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get dayPartAfternoon;

  /// No description provided for @dayPartEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get dayPartEvening;

  /// No description provided for @dayPartNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get dayPartNight;

  /// No description provided for @viewCanvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get viewCanvas;

  /// No description provided for @viewNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get viewNotes;

  /// No description provided for @viewTimeline.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get viewTimeline;

  /// No description provided for @viewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get viewMap;

  /// No description provided for @dayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String dayNumber(int n);

  /// No description provided for @dayWithNumber.
  ///
  /// In en, this message translates to:
  /// **'{date} (day {n})'**
  String dayWithNumber(String date, int n);

  /// No description provided for @dayAndTime.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String dayAndTime(String day, String time);

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// No description provided for @nightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 night} other{{count} nights}}'**
  String nightsCount(int count);

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String hoursShort(int count);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count}min'**
  String minutesShort(int count);

  /// No description provided for @layerLabel.
  ///
  /// In en, this message translates to:
  /// **'Layer {n}: {kind}'**
  String layerLabel(int n, String kind);

  /// No description provided for @conflictStaysOverlap.
  ///
  /// In en, this message translates to:
  /// **'“{item}” starts {duration} before “{other}” ends'**
  String conflictStaysOverlap(String item, String duration, String other);

  /// No description provided for @conflictLodgingOutsideStay.
  ///
  /// In en, this message translates to:
  /// **'“{item}” doesn\'t fit the days in {other}'**
  String conflictLodgingOutsideStay(String item, String other);

  /// No description provided for @conflictActivityOutsideStay.
  ///
  /// In en, this message translates to:
  /// **'“{item}” is outside the stay in {other}'**
  String conflictActivityOutsideStay(String item, String other);

  /// No description provided for @conflictStayEndsAfterDeparture.
  ///
  /// In en, this message translates to:
  /// **'“{stay}” ends after “{transport}” departs'**
  String conflictStayEndsAfterDeparture(String stay, String transport);

  /// No description provided for @conflictDaysBeforeDeparture.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}} without a place between “{stay}” and the departure of “{transport}”'**
  String conflictDaysBeforeDeparture(int days, String stay, String transport);

  /// No description provided for @conflictStayStartsBeforeArrival.
  ///
  /// In en, this message translates to:
  /// **'“{stay}” starts before “{transport}” arrives'**
  String conflictStayStartsBeforeArrival(String stay, String transport);

  /// No description provided for @conflictDaysAfterArrival.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}} without a place between the arrival of “{transport}” and “{stay}”'**
  String conflictDaysAfterArrival(int days, String transport, String stay);

  /// No description provided for @fixPushLater.
  ///
  /// In en, this message translates to:
  /// **'Push “{title}” back'**
  String fixPushLater(String title);

  /// No description provided for @fixFitNightsToStay.
  ///
  /// In en, this message translates to:
  /// **'Fit nights to {title}'**
  String fixFitNightsToStay(String title);

  /// No description provided for @fixMoveIntoStay.
  ///
  /// In en, this message translates to:
  /// **'Move into {title}'**
  String fixMoveIntoStay(String title);

  /// No description provided for @fixShortenToDeparture.
  ///
  /// In en, this message translates to:
  /// **'Shorten “{title}” to the departure'**
  String fixShortenToDeparture(String title);

  /// No description provided for @fixExtendToDeparture.
  ///
  /// In en, this message translates to:
  /// **'Extend “{title}” to the departure'**
  String fixExtendToDeparture(String title);

  /// No description provided for @fixStartLaterAtArrival.
  ///
  /// In en, this message translates to:
  /// **'Start “{title}” only on arrival'**
  String fixStartLaterAtArrival(String title);

  /// No description provided for @fixStartEarlierAtArrival.
  ///
  /// In en, this message translates to:
  /// **'Start “{title}” on arrival'**
  String fixStartEarlierAtArrival(String title);

  /// No description provided for @warnRemoveUnknown.
  ///
  /// In en, this message translates to:
  /// **'remove: “{value}” does not exist – ignored'**
  String warnRemoveUnknown(String value);

  /// No description provided for @warnDuplicateRef.
  ///
  /// In en, this message translates to:
  /// **'ref “{value}” appears more than once – only the first entry counts'**
  String warnDuplicateRef(String value);

  /// No description provided for @warnRefNotFound.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: {field} “{value}” not found – link removed'**
  String warnRefNotFound(String entry, String field, String value);

  /// No description provided for @warnUnknownKind.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: unknown kind “{value}” – skipped'**
  String warnUnknownKind(String entry, String value);

  /// No description provided for @warnMissingKind.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: “kind” missing – skipped'**
  String warnMissingKind(String entry);

  /// No description provided for @warnMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Entry without a title (ref {entry}) – skipped'**
  String warnMissingTitle(String entry);

  /// No description provided for @warnUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: unknown status “{value}” – ignored'**
  String warnUnknownStatus(String entry, String value);

  /// No description provided for @warnUnknownMode.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: unknown mode “{value}” – using “other”'**
  String warnUnknownMode(String entry, String value);

  /// No description provided for @warnSelfReference.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: {field} points to itself – removed'**
  String warnSelfReference(String entry, String field);

  /// No description provided for @warnStartOrEndOnly.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: only start or end given – stays unscheduled'**
  String warnStartOrEndOnly(String entry);

  /// No description provided for @warnEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: end is before start – time not applied'**
  String warnEndBeforeStart(String entry);

  /// No description provided for @warnUnsupportedNoteType.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: note type “{value}” is not supported – skipped'**
  String warnUnsupportedNoteType(String entry, String value);

  /// No description provided for @warnImageTypeFixed.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: image notes can\'t change their type – type ignored'**
  String warnImageTypeFixed(String entry);

  /// No description provided for @warnEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Empty note (ref {entry}) – skipped'**
  String warnEmptyNote(String entry);

  /// No description provided for @warnNotAnInteger.
  ///
  /// In en, this message translates to:
  /// **'Trip: {field} “{value}” is not a whole number – ignored'**
  String warnNotAnInteger(String field, String value);

  /// No description provided for @warnInvalidStartDate.
  ///
  /// In en, this message translates to:
  /// **'Trip: startDate “{value}” is not a date (YYYY-MM-DD) – ignored'**
  String warnInvalidStartDate(String value);

  /// No description provided for @warnDateNeedsStartDate.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: {field}: a date needs the trip\'s start date (trip.startDate) – ignored'**
  String warnDateNeedsStartDate(String entry, String field);

  /// No description provided for @warnInvalidMoment.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: {field}: “{value}” not understood (expected {example}) – ignored'**
  String warnInvalidMoment(
    String entry,
    String field,
    String value,
    String example,
  );

  /// No description provided for @planErrorInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'No valid JSON found ({detail})'**
  String planErrorInvalidJson(String detail);

  /// No description provided for @planErrorNotAnObject.
  ///
  /// In en, this message translates to:
  /// **'No plan found (JSON object expected)'**
  String get planErrorNotAnObject;

  /// No description provided for @planErrorUnknownFormat.
  ///
  /// In en, this message translates to:
  /// **'Unknown format “{detail}” (expected: {expected})'**
  String planErrorUnknownFormat(String detail, String expected);

  /// No description provided for @planErrorNotAPlan.
  ///
  /// In en, this message translates to:
  /// **'Not a Tripboard plan: “items” or “trip” missing'**
  String get planErrorNotAPlan;

  /// No description provided for @planErrorTooNew.
  ///
  /// In en, this message translates to:
  /// **'Plan version {detail} is newer than this app (supports {supported})'**
  String planErrorTooNew(String detail, int supported);

  /// No description provided for @importedTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Imported trip'**
  String get importedTripTitle;

  /// No description provided for @demoInterrailTitle.
  ///
  /// In en, this message translates to:
  /// **'Interrail France & Spain'**
  String get demoInterrailTitle;

  /// No description provided for @demoAvignonNotes.
  ///
  /// In en, this message translates to:
  /// **'Might fit into the free days between Lyon and Barcelona'**
  String get demoAvignonNotes;

  /// No description provided for @demoSagradaFamilia.
  ///
  /// In en, this message translates to:
  /// **'Sagrada Família (booked)'**
  String get demoSagradaFamilia;

  /// No description provided for @demoPaellaCourse.
  ///
  /// In en, this message translates to:
  /// **'Paella cooking class'**
  String get demoPaellaCourse;

  /// No description provided for @demoFlightHomeValencia.
  ///
  /// In en, this message translates to:
  /// **'Flight home Valencia → Home'**
  String get demoFlightHomeValencia;

  /// No description provided for @demoPassTitle.
  ///
  /// In en, this message translates to:
  /// **'Interrail Pass'**
  String get demoPassTitle;

  /// No description provided for @demoPassText.
  ///
  /// In en, this message translates to:
  /// **'Global Pass: 7 travel days within 1 month.\nReservations needed for TGV & Euromed!'**
  String get demoPassText;

  /// No description provided for @demoPackingList.
  ///
  /// In en, this message translates to:
  /// **'Packing list'**
  String get demoPackingList;

  /// No description provided for @demoPackingItems.
  ///
  /// In en, this message translates to:
  /// **'Passport|Interrail app offline|Adapter|Swimwear|Power bank'**
  String get demoPackingItems;

  /// No description provided for @demoReservationsLink.
  ///
  /// In en, this message translates to:
  /// **'Interrail reservations'**
  String get demoReservationsLink;

  /// No description provided for @demoFreeDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Free days 7–8'**
  String get demoFreeDaysTitle;

  /// No description provided for @demoFreeDaysText.
  ///
  /// In en, this message translates to:
  /// **'Ideas: Avignon, Montpellier or Carcassonne?'**
  String get demoFreeDaysText;

  /// No description provided for @demoSriLankaTitle.
  ///
  /// In en, this message translates to:
  /// **'Sri Lanka 2.5 weeks'**
  String get demoSriLankaTitle;

  /// No description provided for @demoYalaName.
  ///
  /// In en, this message translates to:
  /// **'Yala National Park'**
  String get demoYalaName;

  /// No description provided for @demoYalaNotes.
  ///
  /// In en, this message translates to:
  /// **'Safari early in the morning – between Ella and Mirissa'**
  String get demoYalaNotes;

  /// No description provided for @demoFlightOut.
  ///
  /// In en, this message translates to:
  /// **'Flight out'**
  String get demoFlightOut;

  /// No description provided for @demoTrainKandyElla.
  ///
  /// In en, this message translates to:
  /// **'Train Kandy → Ella'**
  String get demoTrainKandyElla;

  /// No description provided for @demoFlightHomeColombo.
  ///
  /// In en, this message translates to:
  /// **'Flight home from Colombo'**
  String get demoFlightHomeColombo;

  /// No description provided for @demoLionRock.
  ///
  /// In en, this message translates to:
  /// **'Lion Rock'**
  String get demoLionRock;

  /// No description provided for @demoToothTemple.
  ///
  /// In en, this message translates to:
  /// **'Temple of the Tooth'**
  String get demoToothTemple;

  /// No description provided for @demoTrainNote.
  ///
  /// In en, this message translates to:
  /// **'Reserve 2nd class seats – right side for the view!'**
  String get demoTrainNote;

  /// No description provided for @demoPreparation.
  ///
  /// In en, this message translates to:
  /// **'Preparation'**
  String get demoPreparation;

  /// No description provided for @demoPreparationItems.
  ///
  /// In en, this message translates to:
  /// **'Apply for ETA visa|Check vaccinations|Mosquito repellent|Exchange rupees'**
  String get demoPreparationItems;

  /// No description provided for @demoRailwayTimetable.
  ///
  /// In en, this message translates to:
  /// **'Sri Lanka Railways timetable'**
  String get demoRailwayTimetable;

  /// No description provided for @demoRoughIdea.
  ///
  /// In en, this message translates to:
  /// **'Rough idea'**
  String get demoRoughIdea;

  /// No description provided for @demoRoughIdeaText.
  ///
  /// In en, this message translates to:
  /// **'Cultural triangle → highlands → south/beach.\nThere are free days between Ella and Mirissa – Yala safari?'**
  String get demoRoughIdeaText;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save your changes?'**
  String get unsavedChangesBody;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @hintTimeline.
  ///
  /// In en, this message translates to:
  /// **'Long-press a block and drag to move it. Long-press a day header to add something on that day. Pinch with two fingers to zoom.'**
  String get hintTimeline;

  /// No description provided for @hintMap.
  ///
  /// In en, this message translates to:
  /// **'Long-press the map to add a place, an accommodation or an activity there.'**
  String get hintMap;

  /// No description provided for @hintCanvas.
  ///
  /// In en, this message translates to:
  /// **'Long-press cards and drag to move them. Pinch with two fingers to zoom.'**
  String get hintCanvas;

  /// No description provided for @fixedApplied.
  ///
  /// In en, this message translates to:
  /// **'Fixed: {fix}'**
  String fixedApplied(String fix);

  /// No description provided for @notScheduledYet.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled yet'**
  String get notScheduledYet;

  /// No description provided for @stepChosen.
  ///
  /// In en, this message translates to:
  /// **'“{title}” chosen'**
  String stepChosen(String title);

  /// No description provided for @stepMarkedBooked.
  ///
  /// In en, this message translates to:
  /// **'“{title}” marked as booked'**
  String stepMarkedBooked(String title);

  /// No description provided for @stepUnbooked.
  ///
  /// In en, this message translates to:
  /// **'“{title}” no longer booked'**
  String stepUnbooked(String title);

  /// No description provided for @stepFixed.
  ///
  /// In en, this message translates to:
  /// **'“{title}” fixed'**
  String stepFixed(String title);

  /// No description provided for @stepUnfixed.
  ///
  /// In en, this message translates to:
  /// **'“{title}” no longer fixed'**
  String stepUnfixed(String title);

  /// No description provided for @stepShiftedDays.
  ///
  /// In en, this message translates to:
  /// **'“{title}” {sign}{days}'**
  String stepShiftedDays(String title, String sign, String days);

  /// No description provided for @stepDeleted.
  ///
  /// In en, this message translates to:
  /// **'“{title}” deleted'**
  String stepDeleted(String title);

  /// No description provided for @deleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String deleteQuestion(String title);

  /// No description provided for @fixedAppointment.
  ///
  /// In en, this message translates to:
  /// **'Fixed appointment'**
  String get fixedAppointment;

  /// No description provided for @belongsTo.
  ///
  /// In en, this message translates to:
  /// **'Belongs to {title}'**
  String belongsTo(String title);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @chooseThisOption.
  ///
  /// In en, this message translates to:
  /// **'Choose this option'**
  String get chooseThisOption;

  /// No description provided for @sectionAccommodations.
  ///
  /// In en, this message translates to:
  /// **'Accommodations'**
  String get sectionAccommodations;

  /// No description provided for @sectionActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get sectionActivities;

  /// No description provided for @sectionLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get sectionLinks;

  /// No description provided for @sectionAttachments.
  ///
  /// In en, this message translates to:
  /// **'Tickets & attachments'**
  String get sectionAttachments;

  /// No description provided for @checklistProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} done'**
  String checklistProgress(int done, int total);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @transportHere.
  ///
  /// In en, this message translates to:
  /// **'Transport here'**
  String get transportHere;

  /// No description provided for @transportOnward.
  ///
  /// In en, this message translates to:
  /// **'Onward transport'**
  String get transportOnward;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @fixedChip.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get fixedChip;

  /// No description provided for @fixedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fixed items stay put when things move'**
  String get fixedTooltip;

  /// No description provided for @fixedNotMoved.
  ///
  /// In en, this message translates to:
  /// **'Fixed items are not moved'**
  String get fixedNotMoved;

  /// No description provided for @minusOneDay.
  ///
  /// In en, this message translates to:
  /// **'−1 day'**
  String get minusOneDay;

  /// No description provided for @plusOneDay.
  ///
  /// In en, this message translates to:
  /// **'+1 day'**
  String get plusOneDay;

  /// No description provided for @checklistMoreDone.
  ///
  /// In en, this message translates to:
  /// **'+ {count} done'**
  String checklistMoreDone(int count);

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get searchNotes;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Collect ideas, links, screenshots and checklists here.\nTap + to add something.'**
  String get notesEmpty;

  /// No description provided for @notesPinned.
  ///
  /// In en, this message translates to:
  /// **'PINNED'**
  String get notesPinned;

  /// No description provided for @notesOthers.
  ///
  /// In en, this message translates to:
  /// **'OTHERS'**
  String get notesOthers;

  /// No description provided for @placeSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search not possible (offline?)'**
  String get placeSearchFailed;

  /// No description provided for @placeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Place, city, sight …'**
  String get placeSearchHint;

  /// No description provided for @osmAttribution.
  ///
  /// In en, this message translates to:
  /// **'Map data © OpenStreetMap contributors'**
  String get osmAttribution;

  /// No description provided for @timeOfDay.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeOfDay;

  /// No description provided for @exactTime.
  ///
  /// In en, this message translates to:
  /// **'Exact time …'**
  String get exactTime;

  /// No description provided for @pickDay.
  ///
  /// In en, this message translates to:
  /// **'Choose day'**
  String get pickDay;

  /// No description provided for @attachmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachments & tickets'**
  String get attachmentsTitle;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @imageFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Image from gallery'**
  String get imageFromGallery;

  /// No description provided for @attachFileTooltip.
  ///
  /// In en, this message translates to:
  /// **'File (PDF ticket …)'**
  String get attachFileTooltip;

  /// No description provided for @attachmentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing attached yet – e.g. a train ticket as PDF or a screenshot of the booking.'**
  String get attachmentsEmpty;

  /// No description provided for @stepImageAttached.
  ///
  /// In en, this message translates to:
  /// **'Image attached'**
  String get stepImageAttached;

  /// No description provided for @attachFileDialog.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFileDialog;

  /// No description provided for @stepFileAttached.
  ///
  /// In en, this message translates to:
  /// **'“{name}” attached'**
  String stepFileAttached(String name);

  /// No description provided for @removeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}”?'**
  String removeQuestion(String name);

  /// No description provided for @stepFileRemoved.
  ///
  /// In en, this message translates to:
  /// **'“{name}” removed'**
  String stepFileRemoved(String name);

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTrip;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get editTrip;

  /// No description provided for @tripTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get tripTitleLabel;

  /// No description provided for @tripTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sri Lanka 2.5 weeks'**
  String get tripTitleHint;

  /// No description provided for @plannedDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned length (days)'**
  String get plannedDaysLabel;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @startDateOpen.
  ///
  /// In en, this message translates to:
  /// **'Start date: not set yet'**
  String get startDateOpen;

  /// No description provided for @startDateValue.
  ///
  /// In en, this message translates to:
  /// **'Start: {date}'**
  String startDateValue(String date);

  /// No description provided for @removeDate.
  ///
  /// In en, this message translates to:
  /// **'Remove date'**
  String get removeDate;

  /// No description provided for @withoutDateHint.
  ///
  /// In en, this message translates to:
  /// **'Without a date you plan with “Day 1, Day 2 …”.'**
  String get withoutDateHint;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// No description provided for @trashEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get trashEmptyAction;

  /// No description provided for @errorWith.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWith(String error);

  /// No description provided for @trashIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The trash is empty.\nDeleted trips stay here for 30 days, then they are removed for good.'**
  String get trashIsEmpty;

  /// No description provided for @trashEmptyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Empty trash?'**
  String get trashEmptyQuestion;

  /// No description provided for @trashEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One trip will be deleted for good} other{{count} trips will be deleted for good}} with all places, notes and attachments.'**
  String trashEmptyBody(int count);

  /// No description provided for @deleteForGood.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get deleteForGood;

  /// No description provided for @trashPurgeHint.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Will be deleted for good on next start} =1{Will be deleted for good tomorrow} other{Will be deleted for good in {days} days}}'**
  String trashPurgeHint(int days);

  /// No description provided for @trashDeletedOn.
  ///
  /// In en, this message translates to:
  /// **'Deleted on {date}'**
  String trashDeletedOn(String date);

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @tripRestored.
  ///
  /// In en, this message translates to:
  /// **'“{title}” restored'**
  String tripRestored(String title);

  /// No description provided for @deleteTripForGoodQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}” for good?'**
  String deleteTripForGoodQuestion(String title);

  /// No description provided for @deleteTripForGoodBody.
  ///
  /// In en, this message translates to:
  /// **'All places, notes and attachments of this trip will be removed. This cannot be undone.'**
  String get deleteTripForGoodBody;

  /// No description provided for @noBackupYet.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get noBackupYet;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {time}'**
  String lastBackup(String time);

  /// No description provided for @backupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backupsTitle;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @backupsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Tripboard backs up all trips automatically when the app starts or goes to the background and the last backup is older than a day. The last {keep} backups are kept.\nThey are stored in the app folder{path} and are deleted when the app is uninstalled. For a permanent copy use “Save as …” on a backup or “Export all trips”.'**
  String backupsExplanation(int keep, Object path);

  /// No description provided for @noAutoBackups.
  ///
  /// In en, this message translates to:
  /// **'No automatic backups yet.'**
  String get noAutoBackups;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as …'**
  String get saveAs;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupCreated;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @restoreBackupQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get restoreBackupQuestion;

  /// No description provided for @restoreBackupBody.
  ///
  /// In en, this message translates to:
  /// **'All trips from the backup of {time} are reset to that state or created again. Trips that are not in the backup stay unchanged. The current state is backed up first.'**
  String restoreBackupBody(String time);

  /// No description provided for @tripsRestored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One trip restored} other{{count} trips restored}}'**
  String tripsRestored(int count);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(String error);

  /// No description provided for @saveBackupDialog.
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get saveBackupDialog;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @errorNotABackup.
  ///
  /// In en, this message translates to:
  /// **'Not a Tripboard backup'**
  String get errorNotABackup;

  /// No description provided for @errorNewerData.
  ///
  /// In en, this message translates to:
  /// **'The data is from a newer app version (format {found}, supported: {supported}). Please update Tripboard.'**
  String errorNewerData(int found, int supported);

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get myTrips;

  /// No description provided for @planWithClaude.
  ///
  /// In en, this message translates to:
  /// **'Plan with Claude …'**
  String get planWithClaude;

  /// No description provided for @exportAllTrips.
  ///
  /// In en, this message translates to:
  /// **'Export all trips'**
  String get exportAllTrips;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get importBackup;

  /// No description provided for @backupsAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backups & restore'**
  String get backupsAndRestore;

  /// No description provided for @loadDemoTrips.
  ///
  /// In en, this message translates to:
  /// **'Load example trips'**
  String get loadDemoTrips;

  /// No description provided for @showHintsAgain.
  ///
  /// In en, this message translates to:
  /// **'Show tips again'**
  String get showHintsAgain;

  /// No description provided for @hintsReset.
  ///
  /// In en, this message translates to:
  /// **'Tips will be shown again'**
  String get hintsReset;

  /// No description provided for @demoTripsCreated.
  ///
  /// In en, this message translates to:
  /// **'Two example trips created'**
  String get demoTripsCreated;

  /// No description provided for @chooseBackup.
  ///
  /// In en, this message translates to:
  /// **'Choose backup'**
  String get chooseBackup;

  /// No description provided for @noTripsInBackup.
  ///
  /// In en, this message translates to:
  /// **'No trips in the backup'**
  String get noTripsInBackup;

  /// No description provided for @tripsImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One trip imported} other{{count} trips imported}}'**
  String tripsImported(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @exportAsBackup.
  ///
  /// In en, this message translates to:
  /// **'Export as backup'**
  String get exportAsBackup;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @noPlacesYet.
  ///
  /// In en, this message translates to:
  /// **'No places planned yet'**
  String get noPlacesYet;

  /// No description provided for @stepTripEdited.
  ///
  /// In en, this message translates to:
  /// **'Trip edited'**
  String get stepTripEdited;

  /// No description provided for @tripDeleted.
  ///
  /// In en, this message translates to:
  /// **'Trip deleted'**
  String get tripDeleted;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @noTripsToExport.
  ///
  /// In en, this message translates to:
  /// **'No trips to export'**
  String get noTripsToExport;

  /// No description provided for @allTripsFileName.
  ///
  /// In en, this message translates to:
  /// **'tripboard-all-trips'**
  String get allTripsFileName;

  /// No description provided for @saveAllTripsDialog.
  ///
  /// In en, this message translates to:
  /// **'Save all trips'**
  String get saveAllTripsDialog;

  /// No description provided for @allTripsExported.
  ///
  /// In en, this message translates to:
  /// **'All trips exported'**
  String get allTripsExported;

  /// No description provided for @noTripYet.
  ///
  /// In en, this message translates to:
  /// **'No trip planned yet'**
  String get noTripYet;

  /// No description provided for @emptyTripsBody.
  ///
  /// In en, this message translates to:
  /// **'Create a new trip or have a look at the examples first (Interrail France/Spain and Sri Lanka).'**
  String get emptyTripsBody;

  /// No description provided for @tripNotFound.
  ///
  /// In en, this message translates to:
  /// **'Trip not found'**
  String get tripNotFound;

  /// No description provided for @undoWithLabel.
  ///
  /// In en, this message translates to:
  /// **'Undo: {label}'**
  String undoWithLabel(String label);

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportBackup;

  /// No description provided for @layerOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get layerOptions;

  /// No description provided for @layerOptionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show accommodation options'**
  String get layerOptionsTooltip;

  /// No description provided for @addSheetPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get addSheetPlan;

  /// No description provided for @addSheetCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get addSheetCollect;

  /// No description provided for @cardNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get cardNote;

  /// No description provided for @cardChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get cardChecklist;

  /// No description provided for @cardLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get cardLink;

  /// No description provided for @cardImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get cardImage;

  /// No description provided for @stepSharedSaved.
  ///
  /// In en, this message translates to:
  /// **'Shared content saved'**
  String get stepSharedSaved;

  /// No description provided for @saveToWhichTrip.
  ///
  /// In en, this message translates to:
  /// **'Save to which trip?'**
  String get saveToWhichTrip;

  /// No description provided for @newTripEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New trip …'**
  String get newTripEllipsis;

  /// No description provided for @tripCreated.
  ///
  /// In en, this message translates to:
  /// **'Trip “{title}” created'**
  String tripCreated(String title);

  /// No description provided for @exchangeSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Copy and paste into the Claude app\n2. Add your wishes and let it plan\n3. Copy Claude\'s answer (or share it to Tripboard) and apply it here'**
  String get exchangeSteps;

  /// No description provided for @copyTripForClaude.
  ///
  /// In en, this message translates to:
  /// **'Copy trip for Claude'**
  String get copyTripForClaude;

  /// No description provided for @copyTripForClaudeSub.
  ///
  /// In en, this message translates to:
  /// **'Guide + current plan'**
  String get copyTripForClaudeSub;

  /// No description provided for @copyGuideOnly.
  ///
  /// In en, this message translates to:
  /// **'Copy guide only'**
  String get copyGuideOnly;

  /// No description provided for @copyGuideOnlySub.
  ///
  /// In en, this message translates to:
  /// **'For a new trip or as project instructions in Claude'**
  String get copyGuideOnlySub;

  /// No description provided for @pastePlan.
  ///
  /// In en, this message translates to:
  /// **'Apply plan from clipboard'**
  String get pastePlan;

  /// No description provided for @openPlanFile.
  ///
  /// In en, this message translates to:
  /// **'Open plan file'**
  String get openPlanFile;

  /// No description provided for @copiedForClaude.
  ///
  /// In en, this message translates to:
  /// **'Copied – now paste it into the Claude app'**
  String get copiedForClaude;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @choosePlan.
  ///
  /// In en, this message translates to:
  /// **'Choose plan'**
  String get choosePlan;

  /// No description provided for @fileNotReadable.
  ///
  /// In en, this message translates to:
  /// **'File not readable: {error}'**
  String fileNotReadable(String error);

  /// No description provided for @promptNewTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip. My wishes: '**
  String get promptNewTrip;

  /// No description provided for @promptMyWishes.
  ///
  /// In en, this message translates to:
  /// **'My wishes: '**
  String get promptMyWishes;

  /// No description provided for @invalidPlan.
  ///
  /// In en, this message translates to:
  /// **'Not a valid plan: {error}'**
  String invalidPlan(String error);

  /// No description provided for @planApplied.
  ///
  /// In en, this message translates to:
  /// **'Plan applied'**
  String get planApplied;

  /// No description provided for @applyPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply plan'**
  String get applyPlanTitle;

  /// No description provided for @importTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get importTarget;

  /// No description provided for @newTripNamed.
  ///
  /// In en, this message translates to:
  /// **'New trip “{title}”'**
  String newTripNamed(String title);

  /// No description provided for @planNoChanges.
  ///
  /// In en, this message translates to:
  /// **'The plan contains no changes.'**
  String get planNoChanges;

  /// No description provided for @planItemsCreated.
  ///
  /// In en, this message translates to:
  /// **'• {count, plural, =1{1 new entry} other{{count} new entries}}'**
  String planItemsCreated(int count);

  /// No description provided for @planItemsUpdated.
  ///
  /// In en, this message translates to:
  /// **'• {count, plural, =1{1 entry changed} other{{count} entries changed}}'**
  String planItemsUpdated(int count);

  /// No description provided for @planItemsRemoved.
  ///
  /// In en, this message translates to:
  /// **'• {count, plural, =1{1 entry deleted} other{{count} entries deleted}}'**
  String planItemsRemoved(int count);

  /// No description provided for @planNotesCreated.
  ///
  /// In en, this message translates to:
  /// **'• {count, plural, =1{1 new note} other{{count} new notes}}'**
  String planNotesCreated(int count);

  /// No description provided for @planNotesUpdated.
  ///
  /// In en, this message translates to:
  /// **'• {count, plural, =1{1 note changed} other{{count} notes changed}}'**
  String planNotesUpdated(int count);

  /// No description provided for @planNotesRemoved.
  ///
  /// In en, this message translates to:
  /// **'• {count, plural, =1{1 note deleted} other{{count} notes deleted}}'**
  String planNotesRemoved(int count);

  /// No description provided for @planFromOtherTrip.
  ///
  /// In en, this message translates to:
  /// **'The plan comes from another trip – everything will be created anew.'**
  String get planFromOtherTrip;

  /// No description provided for @planTripChangedFields.
  ///
  /// In en, this message translates to:
  /// **'• Trip details change: {fields}'**
  String planTripChangedFields(String fields);

  /// No description provided for @planFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'title'**
  String get planFieldTitle;

  /// No description provided for @planFieldKind.
  ///
  /// In en, this message translates to:
  /// **'type'**
  String get planFieldKind;

  /// No description provided for @planFieldPlace.
  ///
  /// In en, this message translates to:
  /// **'place'**
  String get planFieldPlace;

  /// No description provided for @planFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'status'**
  String get planFieldStatus;

  /// No description provided for @planFieldFixed.
  ///
  /// In en, this message translates to:
  /// **'fixed'**
  String get planFieldFixed;

  /// No description provided for @planFieldTime.
  ///
  /// In en, this message translates to:
  /// **'time'**
  String get planFieldTime;

  /// No description provided for @planFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'notes'**
  String get planFieldNotes;

  /// No description provided for @planFieldLinks.
  ///
  /// In en, this message translates to:
  /// **'links'**
  String get planFieldLinks;

  /// No description provided for @planFieldRelation.
  ///
  /// In en, this message translates to:
  /// **'link'**
  String get planFieldRelation;

  /// No description provided for @planFieldMode.
  ///
  /// In en, this message translates to:
  /// **'transport mode'**
  String get planFieldMode;

  /// No description provided for @planFieldTicket.
  ///
  /// In en, this message translates to:
  /// **'ticket details'**
  String get planFieldTicket;

  /// No description provided for @planFieldZone.
  ///
  /// In en, this message translates to:
  /// **'time zone'**
  String get planFieldZone;

  /// No description provided for @planFieldCost.
  ///
  /// In en, this message translates to:
  /// **'cost'**
  String get planFieldCost;

  /// No description provided for @planFieldText.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get planFieldText;

  /// No description provided for @planFieldUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get planFieldUrl;

  /// No description provided for @planFieldPinned.
  ///
  /// In en, this message translates to:
  /// **'pinned'**
  String get planFieldPinned;

  /// No description provided for @planFieldChecklist.
  ///
  /// In en, this message translates to:
  /// **'checklist'**
  String get planFieldChecklist;

  /// No description provided for @planFieldDates.
  ///
  /// In en, this message translates to:
  /// **'dates'**
  String get planFieldDates;

  /// No description provided for @planFieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'currency'**
  String get planFieldCurrency;

  /// No description provided for @planFieldTravellers.
  ///
  /// In en, this message translates to:
  /// **'travellers'**
  String get planFieldTravellers;

  /// No description provided for @planFieldRates.
  ///
  /// In en, this message translates to:
  /// **'rates'**
  String get planFieldRates;

  /// No description provided for @planEntryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get planEntryRemoved;

  /// No description provided for @planConflictsAfter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No conflicts after the import} =1{1 conflict after the import} other{{count} conflicts after the import}}'**
  String planConflictsAfter(int count);

  /// No description provided for @planConflictsBefore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none so far} =1{1 so far} other{{count} so far}}'**
  String planConflictsBefore(int count);

  /// No description provided for @geocodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'{missing} of {total} not found'**
  String geocodeNotFound(int missing, int total);

  /// No description provided for @geocodeNotFoundSub.
  ///
  /// In en, this message translates to:
  /// **'The plan is applied. These entries have no coordinates and are missing from the map; add the place in the editor.'**
  String get geocodeNotFoundSub;

  /// No description provided for @clipboardPlanFound.
  ///
  /// In en, this message translates to:
  /// **'Plan found in the clipboard. Apply plan?'**
  String get clipboardPlanFound;

  /// No description provided for @findCoordinates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Find coordinates for 1 entry} other{Find coordinates for {count} entries}}'**
  String findCoordinates(int count);

  /// No description provided for @findCoordinatesSub.
  ///
  /// In en, this message translates to:
  /// **'Via OpenStreetMap, needs internet'**
  String get findCoordinatesSub;

  /// No description provided for @planWarningsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String planWarningsCount(int count);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @searchingCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Searching coordinates …'**
  String get searchingCoordinates;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving …'**
  String get saving;

  /// No description provided for @stepPlanImported.
  ///
  /// In en, this message translates to:
  /// **'Plan imported'**
  String get stepPlanImported;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @withoutPlaceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} without a place'**
  String withoutPlaceCount(int count);

  /// No description provided for @addHere.
  ///
  /// In en, this message translates to:
  /// **'Add here'**
  String get addHere;

  /// No description provided for @itemsWithoutPlace.
  ///
  /// In en, this message translates to:
  /// **'These items don\'t have a place yet'**
  String get itemsWithoutPlace;

  /// No description provided for @stepNoteCreated.
  ///
  /// In en, this message translates to:
  /// **'Note created'**
  String get stepNoteCreated;

  /// No description provided for @stepCardCreated.
  ///
  /// In en, this message translates to:
  /// **'“{title}” created'**
  String stepCardCreated(String title);

  /// No description provided for @stepNoteChanged.
  ///
  /// In en, this message translates to:
  /// **'Note changed'**
  String get stepNoteChanged;

  /// No description provided for @stepCardChanged.
  ///
  /// In en, this message translates to:
  /// **'“{title}” changed'**
  String stepCardChanged(String title);

  /// No description provided for @stepNoteDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Note discarded'**
  String get stepNoteDiscarded;

  /// No description provided for @stepNoteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get stepNoteDeleted;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @addToPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to plan …'**
  String get addToPlan;

  /// No description provided for @convertToNote.
  ///
  /// In en, this message translates to:
  /// **'Convert to note'**
  String get convertToNote;

  /// No description provided for @convertToChecklist.
  ///
  /// In en, this message translates to:
  /// **'Convert to checklist'**
  String get convertToChecklist;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleHint;

  /// No description provided for @belongsToLabel.
  ///
  /// In en, this message translates to:
  /// **'Belongs to'**
  String get belongsToLabel;

  /// No description provided for @nothingOption.
  ///
  /// In en, this message translates to:
  /// **'— nothing —'**
  String get nothingOption;

  /// No description provided for @urlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get urlLabel;

  /// No description provided for @loadPreview.
  ///
  /// In en, this message translates to:
  /// **'Load preview'**
  String get loadPreview;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @previewFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview could not be loaded'**
  String get previewFailed;

  /// No description provided for @entryHint.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get entryHint;

  /// No description provided for @doneCount.
  ///
  /// In en, this message translates to:
  /// **'{count} done'**
  String doneCount(int count);

  /// No description provided for @deleteNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get deleteNoteQuestion;

  /// No description provided for @addToPlanAs.
  ///
  /// In en, this message translates to:
  /// **'Add to the plan as …'**
  String get addToPlanAs;

  /// No description provided for @pickedOnMap.
  ///
  /// In en, this message translates to:
  /// **'Picked on the map'**
  String get pickedOnMap;

  /// No description provided for @transportTo.
  ///
  /// In en, this message translates to:
  /// **'To {title}'**
  String transportTo(String title);

  /// No description provided for @transportFrom.
  ///
  /// In en, this message translates to:
  /// **'From {title}'**
  String transportFrom(String title);

  /// No description provided for @newItemTitle.
  ///
  /// In en, this message translates to:
  /// **'New: {kind}'**
  String newItemTitle(String kind);

  /// No description provided for @titleHintStay.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kandy'**
  String get titleHintStay;

  /// No description provided for @titleHintTransport.
  ///
  /// In en, this message translates to:
  /// **'e.g. Train Kandy → Ella'**
  String get titleHintTransport;

  /// No description provided for @titleHintAccommodation.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tree House Ella'**
  String get titleHintAccommodation;

  /// No description provided for @titleHintActivity.
  ///
  /// In en, this message translates to:
  /// **'e.g. Safari in Yala NP'**
  String get titleHintActivity;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @fixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t move when something before it is moved (e.g. booked tour, flight home)'**
  String get fixedSubtitle;

  /// No description provided for @inSchedule.
  ///
  /// In en, this message translates to:
  /// **'In the schedule'**
  String get inSchedule;

  /// No description provided for @hasTimes.
  ///
  /// In en, this message translates to:
  /// **'Has days/times'**
  String get hasTimes;

  /// No description provided for @collectedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only collected – no date yet'**
  String get collectedOnly;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @noTitle.
  ///
  /// In en, this message translates to:
  /// **'(no title)'**
  String get noTitle;

  /// No description provided for @belongsToPlace.
  ///
  /// In en, this message translates to:
  /// **'Belongs to place'**
  String get belongsToPlace;

  /// No description provided for @movesWithPlace.
  ///
  /// In en, this message translates to:
  /// **'Moves along when the place moves.'**
  String get movesWithPlace;

  /// No description provided for @transportMode.
  ///
  /// In en, this message translates to:
  /// **'Mode of transport'**
  String get transportMode;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// No description provided for @setPlaceOnMap.
  ///
  /// In en, this message translates to:
  /// **'Set place on the map'**
  String get setPlaceOnMap;

  /// No description provided for @roughIsEnough.
  ///
  /// In en, this message translates to:
  /// **'Rough is fine – the city is enough'**
  String get roughIsEnough;

  /// No description provided for @labelArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get labelArrival;

  /// No description provided for @labelCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get labelCheckIn;

  /// No description provided for @labelDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get labelDeparture;

  /// No description provided for @labelStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get labelStart;

  /// No description provided for @labelLeave.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get labelLeave;

  /// No description provided for @labelCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get labelCheckOut;

  /// No description provided for @labelEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get labelEnd;

  /// No description provided for @daysExplanation.
  ///
  /// In en, this message translates to:
  /// **'Days count every started day. Arriving early and leaving late = more days for the same number of nights.'**
  String get daysExplanation;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get addLink;

  /// No description provided for @stepItemCreated.
  ///
  /// In en, this message translates to:
  /// **'“{title}” created'**
  String stepItemCreated(String title);

  /// No description provided for @stepItemChanged.
  ///
  /// In en, this message translates to:
  /// **'“{title}” changed'**
  String stepItemChanged(String title);

  /// No description provided for @othersMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more item moved} other{{count} more items moved}} ({mode})'**
  String othersMoved(int count, String mode);

  /// No description provided for @stepMovedOnCanvas.
  ///
  /// In en, this message translates to:
  /// **'“{title}” moved on the canvas'**
  String stepMovedOnCanvas(String title);

  /// No description provided for @stepConnectionRemoved.
  ///
  /// In en, this message translates to:
  /// **'Connection removed'**
  String get stepConnectionRemoved;

  /// No description provided for @stepConnectionCreated.
  ///
  /// In en, this message translates to:
  /// **'Connection created'**
  String get stepConnectionCreated;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect: tap the first item'**
  String get connectFirst;

  /// No description provided for @connectSecond.
  ///
  /// In en, this message translates to:
  /// **'Now tap the second item (same pair again = remove the connection)'**
  String get connectSecond;

  /// No description provided for @dragging.
  ///
  /// In en, this message translates to:
  /// **'Dragging …'**
  String get dragging;

  /// No description provided for @nightTitle.
  ///
  /// In en, this message translates to:
  /// **'Night {from} → {to}'**
  String nightTitle(String from, String to);

  /// No description provided for @stepMoved.
  ///
  /// In en, this message translates to:
  /// **'“{title}” moved'**
  String stepMoved(String title);

  /// No description provided for @stepEndChanged.
  ///
  /// In en, this message translates to:
  /// **'“{title}”: end changed'**
  String stepEndChanged(String title);

  /// No description provided for @stepStartChanged.
  ///
  /// In en, this message translates to:
  /// **'“{title}”: start changed'**
  String stepStartChanged(String title);

  /// No description provided for @othersMovedAlong.
  ///
  /// In en, this message translates to:
  /// **'{count} more moved along'**
  String othersMovedAlong(int count);

  /// No description provided for @conflictsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 conflict} other{{count} conflicts}}'**
  String conflictsCount(int count);

  /// No description provided for @freeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day free} other{{count} days free}}'**
  String freeDays(int count);

  /// No description provided for @noTransportBetween.
  ///
  /// In en, this message translates to:
  /// **'No transport from “{from}” to “{to}”'**
  String noTransportBetween(String from, String to);

  /// No description provided for @itemIsFixed.
  ///
  /// In en, this message translates to:
  /// **'“{title}” is fixed and won\'t be moved'**
  String itemIsFixed(String title);

  /// No description provided for @nightsShort.
  ///
  /// In en, this message translates to:
  /// **'{count}N'**
  String nightsShort(int count);

  /// No description provided for @noAccommodationTonight.
  ///
  /// In en, this message translates to:
  /// **'No accommodation for this night yet'**
  String get noAccommodationTonight;

  /// No description provided for @chooseOption.
  ///
  /// In en, this message translates to:
  /// **'Choose an option'**
  String get chooseOption;

  /// No description provided for @newAccommodation.
  ///
  /// In en, this message translates to:
  /// **'New accommodation'**
  String get newAccommodation;

  /// No description provided for @noAccommodationOptions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No accommodation for this night yet} =1{No accommodation yet – 1 option} other{No accommodation yet – {count} options}}'**
  String noAccommodationOptions(int count);

  /// No description provided for @shiftModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Shift mode'**
  String get shiftModeTooltip;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @unscheduledLabel.
  ///
  /// In en, this message translates to:
  /// **'Unscheduled:'**
  String get unscheduledLabel;

  /// No description provided for @viewAgenda.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get viewAgenda;

  /// No description provided for @agendaToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get agendaToday;

  /// No description provided for @agendaTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get agendaTomorrow;

  /// No description provided for @agendaYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get agendaYesterday;

  /// No description provided for @agendaJumpToToday.
  ///
  /// In en, this message translates to:
  /// **'Jump to today'**
  String get agendaJumpToToday;

  /// No description provided for @agendaWhere.
  ///
  /// In en, this message translates to:
  /// **'Where you are'**
  String get agendaWhere;

  /// No description provided for @agendaNextTransport.
  ///
  /// In en, this message translates to:
  /// **'Next transport'**
  String get agendaNextTransport;

  /// No description provided for @agendaProgramme.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get agendaProgramme;

  /// No description provided for @agendaNothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned for this day.'**
  String get agendaNothingPlanned;

  /// No description provided for @agendaCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in {time}'**
  String agendaCheckIn(String time);

  /// No description provided for @agendaCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out {time}'**
  String agendaCheckOut(String time);

  /// No description provided for @agendaDeparts.
  ///
  /// In en, this message translates to:
  /// **'Departs {time}'**
  String agendaDeparts(String time);

  /// No description provided for @agendaArrives.
  ///
  /// In en, this message translates to:
  /// **'Arrives {time}'**
  String agendaArrives(String time);

  /// No description provided for @agendaNoBed.
  ///
  /// In en, this message translates to:
  /// **'No accommodation for this night yet'**
  String get agendaNoBed;

  /// No description provided for @agendaOptionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 option} other{{count} options}}'**
  String agendaOptionsCount(int count);

  /// No description provided for @agendaOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String agendaOpenFile(String name);

  /// No description provided for @agendaNoStartDate.
  ///
  /// In en, this message translates to:
  /// **'Without a start date the agenda shows trip days. Set one under ⋮ → Edit trip to see today.'**
  String get agendaNoStartDate;

  /// No description provided for @agendaStartsIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The trip starts tomorrow.} other{The trip starts in {count} days.}}'**
  String agendaStartsIn(int count);

  /// No description provided for @agendaEnded.
  ///
  /// In en, this message translates to:
  /// **'This trip is over.'**
  String get agendaEnded;

  /// No description provided for @agendaOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {name}. Is an app for this file type installed?'**
  String agendaOpenFailed(String name);

  /// No description provided for @placesListEmpty.
  ///
  /// In en, this message translates to:
  /// **'This trip has no places yet.'**
  String get placesListEmpty;

  /// No description provided for @mapNoPlaces.
  ///
  /// In en, this message translates to:
  /// **'No places with coordinates yet.'**
  String get mapNoPlaces;

  /// No description provided for @mapNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get mapNoCoordinates;

  /// No description provided for @mapOpenInMapsApp.
  ///
  /// In en, this message translates to:
  /// **'Open in maps app'**
  String get mapOpenInMapsApp;

  /// No description provided for @mapUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Map not available'**
  String get mapUnavailableTitle;

  /// No description provided for @mapUnavailableOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection, and this trip\'s map isn\'t saved offline. Here are its places.'**
  String get mapUnavailableOffline;

  /// No description provided for @mapUnavailableFailed.
  ///
  /// In en, this message translates to:
  /// **'The map couldn\'t be loaded. Here are the trip\'s places.'**
  String get mapUnavailableFailed;

  /// No description provided for @mapRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get mapRetry;

  /// No description provided for @mapOfflineLimited.
  ///
  /// In en, this message translates to:
  /// **'Offline – parts of the map may be missing.'**
  String get mapOfflineLimited;

  /// No description provided for @mapOfflineSaved.
  ///
  /// In en, this message translates to:
  /// **'Offline – showing the saved map'**
  String get mapOfflineSaved;

  /// No description provided for @mapPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get mapPlaces;

  /// No description provided for @mapPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Places of this trip'**
  String get mapPlacesTitle;

  /// No description provided for @offlineMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline map'**
  String get offlineMapTitle;

  /// No description provided for @offlineMapSave.
  ///
  /// In en, this message translates to:
  /// **'Save map offline'**
  String get offlineMapSave;

  /// No description provided for @offlineMapSaveAgain.
  ///
  /// In en, this message translates to:
  /// **'Save again'**
  String get offlineMapSaveAgain;

  /// No description provided for @offlineMapExplain.
  ///
  /// In en, this message translates to:
  /// **'Saves the map around all places of the trip – an overview of the whole route and street level around every stay – so it works without internet.'**
  String get offlineMapExplain;

  /// No description provided for @offlineMapEstimate.
  ///
  /// In en, this message translates to:
  /// **'About {tiles} tiles, roughly {size}.'**
  String offlineMapEstimate(int tiles, String size);

  /// No description provided for @offlineMapProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent} % · {size} downloaded'**
  String offlineMapProgress(int percent, String size);

  /// No description provided for @offlineMapProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps running when you leave the map. Without a connection it waits until the network is back.'**
  String get offlineMapProgressHint;

  /// No description provided for @offlineMapSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved offline'**
  String get offlineMapSaved;

  /// No description provided for @offlineMapSavedInfo.
  ///
  /// In en, this message translates to:
  /// **'Saved {date} · {size}'**
  String offlineMapSavedInfo(String date, String size);

  /// No description provided for @offlineMapIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The last download didn\'t finish. Save again or delete it.'**
  String get offlineMapIncomplete;

  /// No description provided for @offlineMapOutdated.
  ///
  /// In en, this message translates to:
  /// **'Some places lie outside the saved area. Save again to include them.'**
  String get offlineMapOutdated;

  /// No description provided for @offlineMapFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving failed: {error}'**
  String offlineMapFailed(String error);

  /// No description provided for @offlineMapNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Saving needs an internet connection.'**
  String get offlineMapNeedsConnection;

  /// No description provided for @offlineMapDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete offline map'**
  String get offlineMapDelete;

  /// No description provided for @offlineMapDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the offline map of this trip?'**
  String get offlineMapDeleteConfirm;

  /// No description provided for @transportDetails.
  ///
  /// In en, this message translates to:
  /// **'Ticket details'**
  String get transportDetails;

  /// No description provided for @departureStationLabel.
  ///
  /// In en, this message translates to:
  /// **'Departure station / airport'**
  String get departureStationLabel;

  /// No description provided for @arrivalStationLabel.
  ///
  /// In en, this message translates to:
  /// **'Arrival station / airport'**
  String get arrivalStationLabel;

  /// No description provided for @transportNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Train / flight no.'**
  String get transportNumberLabel;

  /// No description provided for @seatLabel.
  ///
  /// In en, this message translates to:
  /// **'Seat / platform'**
  String get seatLabel;

  /// No description provided for @bookingRefLabel.
  ///
  /// In en, this message translates to:
  /// **'Booking reference'**
  String get bookingRefLabel;

  /// No description provided for @copyBookingRef.
  ///
  /// In en, this message translates to:
  /// **'Copy booking reference'**
  String get copyBookingRef;

  /// No description provided for @bookingRefCopied.
  ///
  /// In en, this message translates to:
  /// **'Booking reference copied'**
  String get bookingRefCopied;

  /// No description provided for @timeZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timeZoneLabel;

  /// No description provided for @homeZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Home time zone'**
  String get homeZoneLabel;

  /// No description provided for @homeZoneHint.
  ///
  /// In en, this message translates to:
  /// **'Applies to places and times without a zone of their own. Leave empty to plan without time zones.'**
  String get homeZoneHint;

  /// No description provided for @zoneNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get zoneNone;

  /// No description provided for @zoneNoneHome.
  ///
  /// In en, this message translates to:
  /// **'None – trip\'s zone ({zone})'**
  String zoneNoneHome(String zone);

  /// No description provided for @zoneAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic ({zone})'**
  String zoneAutomatic(String zone);

  /// No description provided for @zoneAutomaticNone.
  ///
  /// In en, this message translates to:
  /// **'Automatic (no zone)'**
  String get zoneAutomaticNone;

  /// No description provided for @departureZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Departure time zone'**
  String get departureZoneLabel;

  /// No description provided for @arrivalZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Arrival time zone'**
  String get arrivalZoneLabel;

  /// No description provided for @transportZoneHint.
  ///
  /// In en, this message translates to:
  /// **'Automatic uses the zone of the place you leave or reach.'**
  String get transportZoneHint;

  /// No description provided for @stayZoneHint.
  ///
  /// In en, this message translates to:
  /// **'Times of this place, its accommodation and activities are local times there.'**
  String get stayZoneHint;

  /// No description provided for @pickTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Choose time zone'**
  String get pickTimeZone;

  /// No description provided for @searchTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Search city, zone or UTC offset'**
  String get searchTimeZone;

  /// No description provided for @zonesInTrip.
  ///
  /// In en, this message translates to:
  /// **'Used in this trip'**
  String get zonesInTrip;

  /// No description provided for @allZones.
  ///
  /// In en, this message translates to:
  /// **'All zones'**
  String get allZones;

  /// No description provided for @noZoneMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching time zone'**
  String get noZoneMatches;

  /// No description provided for @localTimeIn.
  ///
  /// In en, this message translates to:
  /// **'Local time {zone}'**
  String localTimeIn(String zone);

  /// No description provided for @realDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}'**
  String realDuration(String duration);

  /// No description provided for @warnUnknownTimeZone.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: {field}: unknown time zone “{value}” (expected e.g. “Asia/Colombo”) – ignored'**
  String warnUnknownTimeZone(String entry, String field, String value);

  /// No description provided for @warnUnknownTripTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Trip: unknown time zone “{value}” (expected e.g. “Europe/Berlin”) – ignored'**
  String warnUnknownTripTimeZone(String value);

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @noNavigationApp.
  ///
  /// In en, this message translates to:
  /// **'No app found for navigation.'**
  String get noNavigationApp;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off.'**
  String get locationServiceOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Tripboard isn\'t allowed to use your location.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location access is blocked. Allow it in the app settings.'**
  String get locationDeniedForever;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your location couldn\'t be determined.'**
  String get locationUnavailable;

  /// No description provided for @locationSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get locationSettings;

  /// No description provided for @placeNoResults.
  ///
  /// In en, this message translates to:
  /// **'No places found for “{query}”'**
  String placeNoResults(String query);

  /// No description provided for @placeNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, try the city, or paste a map link or coordinates.'**
  String get placeNoResultsHint;

  /// No description provided for @placeOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Recently used places, map links and coordinates work without a connection.'**
  String get placeOfflineHint;

  /// No description provided for @placeShortLinkOffline.
  ///
  /// In en, this message translates to:
  /// **'Short links need a connection'**
  String get placeShortLinkOffline;

  /// No description provided for @placeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get placeRecent;

  /// No description provided for @placeUseCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Use these coordinates'**
  String get placeUseCoordinates;

  /// No description provided for @placeFromLink.
  ///
  /// In en, this message translates to:
  /// **'From the link'**
  String get placeFromLink;

  /// No description provided for @placeLinkNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'This link has no coordinates'**
  String get placeLinkNoCoordinates;

  /// No description provided for @placePasteHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: paste a Google Maps, OpenStreetMap or geo: link, or coordinates like 48.8584, 2.2945.'**
  String get placePasteHint;

  /// No description provided for @placeSaveWithoutCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Save “{name}” without coordinates'**
  String placeSaveWithoutCoordinates(String name);

  /// No description provided for @placeSaveWithoutCoordinatesHint.
  ///
  /// In en, this message translates to:
  /// **'Not shown on the map – you can set the spot later.'**
  String get placeSaveWithoutCoordinatesHint;

  /// No description provided for @placeNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'No coordinates – not on the map'**
  String get placeNoCoordinates;

  /// No description provided for @stepScheduled.
  ///
  /// In en, this message translates to:
  /// **'“{title}” scheduled on {day}'**
  String stepScheduled(String title, String day);

  /// No description provided for @scheduleOnDay.
  ///
  /// In en, this message translates to:
  /// **'Schedule on {day}'**
  String scheduleOnDay(String day);

  /// No description provided for @scheduleOnEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Schedule on …'**
  String get scheduleOnEllipsis;

  /// No description provided for @scheduleOtherDay.
  ///
  /// In en, this message translates to:
  /// **'Or on another day'**
  String get scheduleOtherDay;

  /// No description provided for @scheduleDefaultsHint.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, stay{Arrival 14:00, two nights – you can adjust it afterwards.} accommodation{Check-in 15:00 until check-out when its place ends.} activity{10:00–12:00 – you can adjust it afterwards.} other{From the end of its origin place, else 10:00–13:00.}}'**
  String scheduleDefaultsHint(String kind);

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @timelineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No places yet'**
  String get timelineEmptyTitle;

  /// No description provided for @timelineEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start with the first place of your trip – lodging, transport and activities build on it.'**
  String get timelineEmptyBody;

  /// No description provided for @timelineEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add first place'**
  String get timelineEmptyAction;

  /// No description provided for @costSection.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get costSection;

  /// No description provided for @costAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get costAmountLabel;

  /// No description provided for @costCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get costCurrencyLabel;

  /// No description provided for @costCurrencyHintNone.
  ///
  /// In en, this message translates to:
  /// **'Code, e.g. EUR'**
  String get costCurrencyHintNone;

  /// No description provided for @costTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get costTotal;

  /// No description provided for @costPerPerson.
  ///
  /// In en, this message translates to:
  /// **'Per person'**
  String get costPerPerson;

  /// No description provided for @costPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get costPaid;

  /// No description provided for @costOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get costOpen;

  /// No description provided for @costInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Not a valid amount'**
  String get costInvalidAmount;

  /// No description provided for @costInvalidCurrency.
  ///
  /// In en, this message translates to:
  /// **'Three-letter code like EUR'**
  String get costInvalidCurrency;

  /// No description provided for @costTravellersTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 traveller} other{{count} travellers}}: {total}'**
  String costTravellersTotal(int count, String total);

  /// No description provided for @costPerPersonOf.
  ///
  /// In en, this message translates to:
  /// **'{amount} per person'**
  String costPerPersonOf(String amount);

  /// No description provided for @costTimesPerPerson.
  ///
  /// In en, this message translates to:
  /// **'{count} × {amount} per person'**
  String costTimesPerPerson(int count, String amount);

  /// No description provided for @costApprox.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount}'**
  String costApprox(String amount);

  /// No description provided for @costHint.
  ///
  /// In en, this message translates to:
  /// **'Estimates are fine – mark it paid once it is.'**
  String get costHint;

  /// No description provided for @tripCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Home currency'**
  String get tripCurrencyLabel;

  /// No description provided for @tripCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'The budget shows all costs in this currency, e.g. EUR.'**
  String get tripCurrencyHint;

  /// No description provided for @travellersLabel.
  ///
  /// In en, this message translates to:
  /// **'Travellers'**
  String get travellersLabel;

  /// No description provided for @stepMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'“{title}” marked as paid'**
  String stepMarkedPaid(String title);

  /// No description provided for @stepMarkedUnpaid.
  ///
  /// In en, this message translates to:
  /// **'“{title}” marked as unpaid'**
  String stepMarkedUnpaid(String title);

  /// No description provided for @stepRateChanged.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate {currency}'**
  String stepRateChanged(String currency);

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @budgetEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No costs yet'**
  String get budgetEmptyTitle;

  /// No description provided for @budgetEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add costs to places, transports, lodging or activities in the editor – or let Claude fill in estimated prices.'**
  String get budgetEmptyBody;

  /// No description provided for @budgetByLayer.
  ///
  /// In en, this message translates to:
  /// **'By layer'**
  String get budgetByLayer;

  /// No description provided for @budgetNotCounted.
  ///
  /// In en, this message translates to:
  /// **'Options & ideas (not counted)'**
  String get budgetNotCounted;

  /// No description provided for @budgetMissingRate.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate for {currency} – {amount} not included'**
  String budgetMissingRate(String currency, String amount);

  /// No description provided for @budgetEnterRate.
  ///
  /// In en, this message translates to:
  /// **'Enter rate'**
  String get budgetEnterRate;

  /// No description provided for @budgetRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get budgetRates;

  /// No description provided for @budgetRatesHint.
  ///
  /// In en, this message translates to:
  /// **'Entered by you and stored with the trip, so the budget also works offline.'**
  String get budgetRatesHint;

  /// No description provided for @budgetRateValue.
  ///
  /// In en, this message translates to:
  /// **'1 {home} = {rate} {currency}'**
  String budgetRateValue(String home, String rate, String currency);

  /// No description provided for @budgetRateMissing.
  ///
  /// In en, this message translates to:
  /// **'No rate'**
  String get budgetRateMissing;

  /// No description provided for @budgetAddRate.
  ///
  /// In en, this message translates to:
  /// **'Add rate'**
  String get budgetAddRate;

  /// No description provided for @budgetRateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate for {currency}'**
  String budgetRateDialogTitle(String currency);

  /// No description provided for @budgetRateDialogHint.
  ///
  /// In en, this message translates to:
  /// **'How many {currency} do you get for 1 {home}?'**
  String budgetRateDialogHint(String currency, String home);

  /// No description provided for @budgetRemoveRate.
  ///
  /// In en, this message translates to:
  /// **'Remove rate'**
  String get budgetRemoveRate;

  /// No description provided for @budgetNoCurrency.
  ///
  /// In en, this message translates to:
  /// **'Set a home currency to convert foreign amounts.'**
  String get budgetNoCurrency;

  /// No description provided for @budgetCurrencyGuessed.
  ///
  /// In en, this message translates to:
  /// **'No home currency set – showing {currency}, the one used most.'**
  String budgetCurrencyGuessed(String currency);

  /// No description provided for @budgetSettingsLine.
  ///
  /// In en, this message translates to:
  /// **'Home currency: {currency} · Travellers: {count}'**
  String budgetSettingsLine(String currency, int count);

  /// No description provided for @budgetCurrencyNotSet.
  ///
  /// In en, this message translates to:
  /// **'not set'**
  String get budgetCurrencyNotSet;

  /// No description provided for @budgetItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get budgetItems;

  /// No description provided for @budgetPaidOf.
  ///
  /// In en, this message translates to:
  /// **'{paid} of {total} paid'**
  String budgetPaidOf(String paid, String total);

  /// No description provided for @warnInvalidCost.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: cost {value} has no valid amount – ignored'**
  String warnInvalidCost(String entry, String value);

  /// No description provided for @warnUnknownCurrency.
  ///
  /// In en, this message translates to:
  /// **'“{entry}”: {field}: unknown currency “{value}” (expected a code like “EUR”) – ignored'**
  String warnUnknownCurrency(String entry, String field, String value);

  /// No description provided for @warnUnknownTripCurrency.
  ///
  /// In en, this message translates to:
  /// **'Trip: {field}: unknown currency “{value}” (expected a code like “EUR”) – ignored'**
  String warnUnknownTripCurrency(String field, String value);

  /// No description provided for @warnInvalidRate.
  ///
  /// In en, this message translates to:
  /// **'Trip: exchange rate for {field} “{value}” is not a positive number – ignored'**
  String warnInvalidRate(String field, String value);

  /// No description provided for @a11yDayLater.
  ///
  /// In en, this message translates to:
  /// **'1 day later'**
  String get a11yDayLater;

  /// No description provided for @a11yDayEarlier.
  ///
  /// In en, this message translates to:
  /// **'1 day earlier'**
  String get a11yDayEarlier;

  /// No description provided for @a11yConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get a11yConflict;

  /// No description provided for @a11ySelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get a11ySelected;

  /// No description provided for @a11yHintAdd.
  ///
  /// In en, this message translates to:
  /// **'add'**
  String get a11yHintAdd;

  /// No description provided for @a11yHintDetails.
  ///
  /// In en, this message translates to:
  /// **'show details'**
  String get a11yHintDetails;

  /// No description provided for @a11yHintAddOnDay.
  ///
  /// In en, this message translates to:
  /// **'add something on this day'**
  String get a11yHintAddOnDay;

  /// No description provided for @a11yMap.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Map, no places} =1{Map with 1 place} other{Map with {count} places}}'**
  String a11yMap(int count);

  /// No description provided for @a11yPlacesList.
  ///
  /// In en, this message translates to:
  /// **'Places as a list'**
  String get a11yPlacesList;

  /// No description provided for @a11yColor.
  ///
  /// In en, this message translates to:
  /// **'Colour: {name}'**
  String a11yColor(String name);

  /// No description provided for @colorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get colorDefault;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// No description provided for @colorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get colorGrey;

  /// No description provided for @shareMenu.
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get shareMenu;

  /// No description provided for @shareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share with fellow travellers'**
  String get shareSheetTitle;

  /// No description provided for @shareSheetHint.
  ///
  /// In en, this message translates to:
  /// **'Planned and booked items only; options and ideas stay private.'**
  String get shareSheetHint;

  /// No description provided for @shareAsText.
  ///
  /// In en, this message translates to:
  /// **'Itinerary as text'**
  String get shareAsText;

  /// No description provided for @shareAsTextSub.
  ///
  /// In en, this message translates to:
  /// **'Day by day, for messengers and email'**
  String get shareAsTextSub;

  /// No description provided for @shareAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Itinerary as PDF'**
  String get shareAsPdf;

  /// No description provided for @shareAsPdfSub.
  ///
  /// In en, this message translates to:
  /// **'To print or send'**
  String get shareAsPdfSub;

  /// No description provided for @shareCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar (ICS)'**
  String get shareCalendar;

  /// No description provided for @shareCalendarSub.
  ///
  /// In en, this message translates to:
  /// **'Planned and booked items as calendar events'**
  String get shareCalendarSub;

  /// No description provided for @shareCalendarNeedsDate.
  ///
  /// In en, this message translates to:
  /// **'Asks for the start date first'**
  String get shareCalendarNeedsDate;

  /// No description provided for @shareCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get shareCopyText;

  /// No description provided for @shareTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Itinerary copied'**
  String get shareTextCopied;

  /// No description provided for @shareNoStartDate.
  ///
  /// In en, this message translates to:
  /// **'Without a start date the itinerary shows trip days (Day 1, Day 2 …).'**
  String get shareNoStartDate;

  /// No description provided for @shareStartDateTitle.
  ///
  /// In en, this message translates to:
  /// **'When does the trip start?'**
  String get shareStartDateTitle;

  /// No description provided for @shareStartDateBody.
  ///
  /// In en, this message translates to:
  /// **'A calendar needs real dates. Pick the date of day 1; it is saved with the trip.'**
  String get shareStartDateBody;

  /// No description provided for @sharePickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get sharePickDate;

  /// No description provided for @stepStartDateSet.
  ///
  /// In en, this message translates to:
  /// **'Start date set'**
  String get stepStartDateSet;

  /// No description provided for @shareNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'Nothing with a date is planned or booked yet.'**
  String get shareNothingToExport;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed: {error}'**
  String shareFailed(String error);

  /// No description provided for @shareSubject.
  ///
  /// In en, this message translates to:
  /// **'Itinerary: {title}'**
  String shareSubject(String title);

  /// No description provided for @shareRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get shareRoute;

  /// No description provided for @shareDayByDay.
  ///
  /// In en, this message translates to:
  /// **'Day by day'**
  String get shareDayByDay;

  /// No description provided for @shareFreeDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get shareFreeDay;

  /// No description provided for @shareNight.
  ///
  /// In en, this message translates to:
  /// **'Night: {title}'**
  String shareNight(String title);

  /// No description provided for @shareNoBed.
  ///
  /// In en, this message translates to:
  /// **'No accommodation yet'**
  String get shareNoBed;

  /// No description provided for @shareCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in: {title}'**
  String shareCheckIn(String title);

  /// No description provided for @shareCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out: {title}'**
  String shareCheckOut(String title);

  /// No description provided for @shareBooked.
  ///
  /// In en, this message translates to:
  /// **'booked'**
  String get shareBooked;

  /// No description provided for @shareNightsUntil.
  ///
  /// In en, this message translates to:
  /// **'{nights}, until {day}'**
  String shareNightsUntil(String nights, String day);

  /// No description provided for @shareStayLine.
  ///
  /// In en, this message translates to:
  /// **'{place} – {nights} ({from} – {to})'**
  String shareStayLine(String place, String nights, String from, String to);

  /// No description provided for @shareDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}'**
  String shareDuration(String duration);

  /// No description provided for @shareGeneratedBy.
  ///
  /// In en, this message translates to:
  /// **'Created with Tripboard on {date}'**
  String shareGeneratedBy(String date);

  /// No description provided for @sharePdfPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String sharePdfPage(String page, String pages);

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @remindersSwitch.
  ///
  /// In en, this message translates to:
  /// **'Remind me of this trip'**
  String get remindersSwitch;

  /// No description provided for @remindersSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications before departures, check-in and check-out'**
  String get remindersSwitchHint;

  /// No description provided for @remindersNeedStartDate.
  ///
  /// In en, this message translates to:
  /// **'Reminders need real dates. Set the date of day 1 to schedule them.'**
  String get remindersNeedStartDate;

  /// No description provided for @remindersSetStartDate.
  ///
  /// In en, this message translates to:
  /// **'Set start date'**
  String get remindersSetStartDate;

  /// No description provided for @remindersNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Tripboard, so reminders cannot appear.'**
  String get remindersNotificationsOff;

  /// No description provided for @remindersAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get remindersAllow;

  /// No description provided for @remindersInexact.
  ///
  /// In en, this message translates to:
  /// **'Without the permission for alarms & reminders, notifications may arrive late, for reminders far ahead even by hours.'**
  String get remindersInexact;

  /// No description provided for @remindersAllowExact.
  ///
  /// In en, this message translates to:
  /// **'Allow exact times'**
  String get remindersAllowExact;

  /// No description provided for @remindersWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get remindersWhen;

  /// No description provided for @remindersLead.
  ///
  /// In en, this message translates to:
  /// **'{duration} before'**
  String remindersLead(String duration);

  /// No description provided for @remindersFor.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get remindersFor;

  /// No description provided for @remindersDepartures.
  ///
  /// In en, this message translates to:
  /// **'Departures'**
  String get remindersDepartures;

  /// No description provided for @remindersCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get remindersCheckIn;

  /// No description provided for @remindersCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get remindersCheckOut;

  /// No description provided for @remindersUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Next reminders'**
  String get remindersUpcoming;

  /// No description provided for @remindersNone.
  ///
  /// In en, this message translates to:
  /// **'No upcoming reminders: no planned or booked departure, check-in or check-out lies ahead.'**
  String get remindersNone;

  /// No description provided for @remindersMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String remindersMore(int count);

  /// No description provided for @remindersOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get remindersOff;

  /// No description provided for @remindersFiresAt.
  ///
  /// In en, this message translates to:
  /// **'Notification {when}'**
  String remindersFiresAt(String when);

  /// No description provided for @reminderDepartureTitle.
  ///
  /// In en, this message translates to:
  /// **'Departure {time}: {title}'**
  String reminderDepartureTitle(String time, String title);

  /// No description provided for @reminderCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in {time}: {title}'**
  String reminderCheckInTitle(String time, String title);

  /// No description provided for @reminderCheckOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-out {time}: {title}'**
  String reminderCheckOutTitle(String time, String title);

  /// No description provided for @reminderIn.
  ///
  /// In en, this message translates to:
  /// **'in {duration}'**
  String reminderIn(String duration);

  /// No description provided for @packingList.
  ///
  /// In en, this message translates to:
  /// **'Packing list'**
  String get packingList;

  /// No description provided for @packingTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get packingTemplates;

  /// No description provided for @packingTemplateBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get packingTemplateBasics;

  /// No description provided for @packingTemplateBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get packingTemplateBeach;

  /// No description provided for @packingTemplateHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get packingTemplateHiking;

  /// No description provided for @packingTemplateCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get packingTemplateCity;

  /// No description provided for @packingTemplateBasicsItems.
  ///
  /// In en, this message translates to:
  /// **'Passport / ID|Wallet & cards|Phone charger|Power bank|Travel adapter|Medication|First-aid kit|Toothbrush & toiletries|Underwear|Socks|T-shirts|Trousers|Sleepwear|Rain jacket|Headphones|Copies of documents'**
  String get packingTemplateBasicsItems;

  /// No description provided for @packingTemplateBeachItems.
  ///
  /// In en, this message translates to:
  /// **'Swimwear|Sunscreen|Sunglasses|Sun hat|Beach towel|Flip-flops|After-sun lotion|Waterproof phone pouch|Snorkel gear|Book'**
  String get packingTemplateBeachItems;

  /// No description provided for @packingTemplateHikingItems.
  ///
  /// In en, this message translates to:
  /// **'Hiking boots|Daypack|Water bottle|Rain jacket|Warm layer / fleece|Hiking socks|Blister plasters|Headlamp|Offline maps|Snacks|Pocket knife|Sunscreen'**
  String get packingTemplateHikingItems;

  /// No description provided for @packingTemplateCityItems.
  ///
  /// In en, this message translates to:
  /// **'Comfortable shoes|Day bag|Offline maps|Public transport ticket|Umbrella|Smart outfit|Reusable water bottle|Museum tickets'**
  String get packingTemplateCityItems;

  /// No description provided for @packingCreate.
  ///
  /// In en, this message translates to:
  /// **'Create list'**
  String get packingCreate;

  /// No description provided for @packingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add entries'**
  String get packingAdd;

  /// No description provided for @packingEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String packingEntryCount(int count);

  /// No description provided for @packingFromOtherTrip.
  ///
  /// In en, this message translates to:
  /// **'Copy list from another trip'**
  String get packingFromOtherTrip;

  /// No description provided for @packingNoOtherLists.
  ///
  /// In en, this message translates to:
  /// **'There are no checklists in other trips yet.'**
  String get packingNoOtherLists;

  /// No description provided for @packingSource.
  ///
  /// In en, this message translates to:
  /// **'{trip} · {count, plural, =1{1 entry} other{{count} entries}}'**
  String packingSource(String trip, int count);

  /// No description provided for @packingAddFrom.
  ///
  /// In en, this message translates to:
  /// **'Add from template or trip …'**
  String get packingAddFrom;

  /// No description provided for @packingEntriesAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry added} other{{count} entries added}}'**
  String packingEntriesAdded(int count);

  /// No description provided for @packingNothingNew.
  ///
  /// In en, this message translates to:
  /// **'All entries are already on the list'**
  String get packingNothingNew;

  /// No description provided for @stepEntryTicked.
  ///
  /// In en, this message translates to:
  /// **'“{entry}” ticked off'**
  String stepEntryTicked(String entry);

  /// No description provided for @stepEntryUnticked.
  ///
  /// In en, this message translates to:
  /// **'“{entry}” unticked'**
  String stepEntryUnticked(String entry);

  /// No description provided for @entryMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get entryMoveUp;

  /// No description provided for @entryMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get entryMoveDown;

  /// No description provided for @entryDragHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get entryDragHandle;

  /// No description provided for @entryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get entryDelete;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles, places, notes …'**
  String get searchHint;

  /// No description provided for @searchScopeTrip.
  ///
  /// In en, this message translates to:
  /// **'This trip'**
  String get searchScopeTrip;

  /// No description provided for @searchScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All trips'**
  String get searchScopeAll;

  /// No description provided for @searchIntro.
  ///
  /// In en, this message translates to:
  /// **'Searches titles, places, notes, links, ticket details, checklists and attachments of your trips.'**
  String get searchIntro;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String searchNoResults(String query);

  /// No description provided for @searchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling or try a shorter word.'**
  String get searchNoResultsHint;

  /// No description provided for @searchNoResultsTrip.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this trip – search all trips?'**
  String get searchNoResultsTrip;

  /// No description provided for @searchHitCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 result} other{{n} results}}'**
  String searchHitCount(int n);

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @searchFieldPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get searchFieldPlace;

  /// No description provided for @searchFieldText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get searchFieldText;

  /// No description provided for @searchFieldAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get searchFieldAttachment;

  /// No description provided for @searchFieldLinks.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get searchFieldLinks;

  /// No description provided for @searchOpenTrip.
  ///
  /// In en, this message translates to:
  /// **'Open trip'**
  String get searchOpenTrip;

  /// No description provided for @conflictLodgingsOverlap.
  ///
  /// In en, this message translates to:
  /// **'“{item}” and “{other}” are both confirmed for {count, plural, =1{1 night} other{{count} nights}}'**
  String conflictLodgingsOverlap(String item, String other, int count);

  /// No description provided for @conflictActivityDuringTransport.
  ///
  /// In en, this message translates to:
  /// **'“{item}” is planned while “{transport}” is under way'**
  String conflictActivityDuringTransport(String item, String transport);

  /// No description provided for @conflictTransportsOverlap.
  ///
  /// In en, this message translates to:
  /// **'“{item}” departs before “{other}” arrives'**
  String conflictTransportsOverlap(String item, String other);

  /// No description provided for @fixMakeOption.
  ///
  /// In en, this message translates to:
  /// **'Make “{title}” an option'**
  String fixMakeOption(String title);

  /// No description provided for @fixMoveBeforeTransport.
  ///
  /// In en, this message translates to:
  /// **'Move before “{title}”'**
  String fixMoveBeforeTransport(String title);

  /// No description provided for @fixMoveAfterTransport.
  ///
  /// In en, this message translates to:
  /// **'Move after “{title}”'**
  String fixMoveAfterTransport(String title);

  /// No description provided for @noFixFixed.
  ///
  /// In en, this message translates to:
  /// **'No automatic fix: “{title}” is fixed. Change it by hand or release “Fixed”.'**
  String noFixFixed(String title);

  /// No description provided for @noFixBothBooked.
  ///
  /// In en, this message translates to:
  /// **'No automatic fix: both are booked. Cancel or move one of them.'**
  String get noFixBothBooked;

  /// No description provided for @noFixManual.
  ///
  /// In en, this message translates to:
  /// **'No automatic fix. Open the items and adjust the times.'**
  String get noFixManual;

  /// No description provided for @openItemTitled.
  ///
  /// In en, this message translates to:
  /// **'Open “{title}”'**
  String openItemTitled(String title);

  /// No description provided for @showConflicts.
  ///
  /// In en, this message translates to:
  /// **'Show conflicts'**
  String get showConflicts;

  /// No description provided for @noConflicts.
  ///
  /// In en, this message translates to:
  /// **'No conflicts'**
  String get noConflicts;

  /// No description provided for @demotedToOption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 other accommodation is now an option} other{{count} other accommodations are now options}}'**
  String demotedToOption(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
