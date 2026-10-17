// Localisation helpers for tests: widget tests run in German (the strings
// the expectations were written against); pure tests look strings up
// directly.
import 'package:flutter/material.dart';
import 'package:travel_planner/l10n/app_localizations.dart';

const testLocale = Locale('de');

/// German and English strings without a widget tree.
final de = lookupAppLocalizations(const Locale('de'));
final en = lookupAppLocalizations(const Locale('en'));

/// A MaterialApp with the app's localisations, pinned to [locale].
MaterialApp testApp({required Widget home, Locale locale = testLocale}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
