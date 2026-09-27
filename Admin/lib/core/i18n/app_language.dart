import 'package:flutter/widgets.dart';

/// What the console can be read in.
///
/// Only the two the app actually ships copy for are listed. The language
/// picker shows the rest of India's languages as "coming soon" rather than
/// letting somebody switch into a half-translated build.
enum AppLanguage {
  en('English', 'English', Locale('en', 'IN')),
  hi('Hindi', 'हिन्दी', Locale('hi', 'IN'));

  const AppLanguage(this.englishName, this.nativeName, this.locale);

  /// How the language is named in English — what the settings row reads.
  final String englishName;

  /// How the language names itself, shown under [englishName].
  final String nativeName;

  final Locale locale;

  /// The tag persisted in the snapshot and matched against the device.
  String get code => locale.languageCode;

  static AppLanguage fromCode(String? code) {
    for (final l in AppLanguage.values) {
      if (l.code == code) return l;
    }
    return AppLanguage.en;
  }
}
