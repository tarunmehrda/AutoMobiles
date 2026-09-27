import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:garagepro_admin/core/i18n/app_language.dart';
import 'package:garagepro_admin/core/i18n/strings.dart';
import 'package:garagepro_admin/core/i18n/strings_hi.dart';
import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/theme/app_type.dart';
import 'package:garagepro_admin/core/utils/formatters.dart';

/// The Hindi build, checked where it can actually go wrong.
///
/// A dictionary lookup cannot throw, so the risk is not "does it translate"
/// — it is a template whose placeholders were dropped in translation, a
/// number that silently reverts to Latin script, or a font that ships no
/// Devanagari and paints the whole console as tofu boxes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeDateFormatting);
  tearDown(() => Tr.use(AppLanguage.en));

  group('the dictionary', () {
    test('translates, and falls through when it cannot', () {
      Tr.use(AppLanguage.hi);
      expect('Settings'.tr, 'सेटिंग्स');
      expect('Job Cards'.tr, 'जॉब कार्ड');
      // Nothing claims to translate a make, so it comes back untouched
      // rather than blank or as a key.
      expect('Bosch'.tr, 'Bosch');
      expect(
        'a string nobody wrote copy for'.tr,
        'a string nobody wrote copy for',
      );
    });

    test('is inert in English', () {
      Tr.use(AppLanguage.en);
      expect('Settings'.tr, 'Settings');
      expect('{0} job cards'.trf([4]), '4 job cards');
    });

    test('keeps every placeholder a template was written with', () {
      final ph = RegExp(r'\{\d+\}');
      final broken = <String>[];
      stringsHi.forEach((en, hi) {
        final a = ph.allMatches(en).map((m) => m[0]!).toSet();
        final b = ph.allMatches(hi).map((m) => m[0]!).toSet();
        if (a.length != b.length || !a.containsAll(b)) {
          broken.add('$en -> $hi');
        }
      });
      expect(broken, isEmpty, reason: broken.join('\n'));
    });

    test('keeps every line break a label was written with', () {
      final broken = <String>[];
      stringsHi.forEach((en, hi) {
        if ('\n'.allMatches(en).length != '\n'.allMatches(hi).length) {
          broken.add('$en -> $hi');
        }
      });
      expect(broken, isEmpty, reason: broken.join('\n'));
    });

    test('never leaves a value in English', () {
      // A value identical to its key is a translation somebody forgot to
      // write. Entries that are deliberately identical are code, not copy.
      const sameOnPurpose = {
        'UPI ID',
        'WhatsApp',
        'GST {0}%',
        'GSTIN {0}',
        'GSTIN: {0}',
        '{0} • v{1}',
        'Thermal 58mm',
        'Thermal 80mm',
      };
      final untranslated = stringsHi.entries
          .where((e) => e.key == e.value && !sameOnPurpose.contains(e.key))
          .map((e) => e.key)
          .toList();
      expect(untranslated, isEmpty, reason: untranslated.join(', '));
    });
  });

  group('templates and plurals', () {
    test('fill their arguments in Hindi', () {
      Tr.use(AppLanguage.hi);
      expect('{0} job cards'.trf([7]), '7 जॉब कार्ड');
      expect('Job card {0}'.trf(['JC-14']), 'जॉब कार्ड JC-14');
    });

    test('pick the right arm either side of one', () {
      Tr.use(AppLanguage.en);
      expect(Tr.plural(1, '{0} day', '{0} days'), '1 day');
      expect(Tr.plural(3, '{0} day', '{0} days'), '3 days');
      Tr.use(AppLanguage.hi);
      expect(Tr.plural(1, '{0} day', '{0} days'), '1 दिन');
      expect(Tr.plural(3, '{0} day', '{0} days'), '3 दिन');
    });
  });

  group('formatting', () {
    test('money keeps Indian grouping and Latin digits in both languages', () {
      for (final l in AppLanguage.values) {
        Tr.use(l);
        expect(Fmt.money(325000), '₹3,25,000');
        expect(Fmt.number(42300), '42,300');
      }
    });

    test('dates follow the language', () {
      final d = DateTime(2026, 9, 15);
      Tr.use(AppLanguage.en);
      final en = Fmt.date(d);
      Tr.use(AppLanguage.hi);
      final hi = Fmt.date(d);
      expect(en, '15 Sep 2026');
      // The month is a word, so it has to change with the language.
      expect(hi, isNot(en));
      expect(hi, contains('2026'));
    });

    test('relative days read in Hindi', () {
      Tr.use(AppLanguage.hi);
      expect(Fmt.friendlyDay(DateTime.now()), 'आज');
      expect(
        Fmt.relative(DateTime.now().subtract(const Duration(days: 3))),
        '3 दिन पहले',
      );
    });
  });

  group('Devanagari', () {
    test('ships a font that has it', () {
      final f = File('assets/fonts/NotoDeva-400.ttf');
      expect(
        f.existsSync(),
        isTrue,
        reason: 'the Hindi build needs a Devanagari face bundled',
      );
      expect(f.lengthSync(), greaterThan(50000));
    });

    test('is declared for every weight the type scale uses', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final w in [400, 500, 600, 700, 800]) {
        expect(pubspec, contains('assets/fonts/NotoDeva-$w.ttf'));
      }
      expect(pubspec, contains('family: NotoDeva'));
    });

    test('is in the fallback chain of every text style', () {
      // Neither Sora nor Inter carries a Devanagari glyph, so a style that
      // forgets the fallback renders Hindi as empty boxes.
      final styles = <String, TextStyle>{
        'd1': AppType.d1,
        'd2': AppType.d2,
        'd3': AppType.d3,
        'h1': AppType.h1,
        'h2': AppType.h2,
        'h3': AppType.h3,
        'bodyL': AppType.bodyL,
        'bodyM': AppType.bodyM,
        'bodyS': AppType.bodyS,
        'labelL': AppType.labelL,
        'labelM': AppType.labelM,
        'labelS': AppType.labelS,
        'over': AppType.over,
        'money': AppType.money,
        'moneyL': AppType.moneyL,
        'moneyS': AppType.moneyS,
      };
      styles.forEach((name, s) {
        expect(
          s.fontFamilyFallback,
          contains(AppType.deva),
          reason: '$name cannot reach Devanagari',
        );
      });
    });

    test('is reachable from the theme itself', () {
      for (final t in [AppTheme.light(), AppTheme.dark()]) {
        expect(
          t.textTheme.bodyMedium!.fontFamilyFallback,
          contains(AppType.deva),
        );
      }
    });
  });

  group('the language itself', () {
    test('round-trips through its stored tag', () {
      for (final l in AppLanguage.values) {
        expect(AppLanguage.fromCode(l.code), l);
      }
      // An unknown tag from an older snapshot must not throw.
      expect(AppLanguage.fromCode('xx'), AppLanguage.en);
      expect(AppLanguage.fromCode(null), AppLanguage.en);
    });
  });

  test('the generated dictionary matches its JSON source', () {
    // Catches a hand-edit of strings_hi.dart that never went back into
    // tool/i18n, which the next regeneration would silently throw away.
    // The JSON holds strings in their Dart *source* spelling, so a line
    // break is still the two characters `\` and `n` there. The compiler
    // turns those into a real newline on the way into [stringsHi], and it
    // is the newline the running code looks up — so undo the escape before
    // comparing, or every two-line label reads as a mismatch.
    String decode(String s) => s.replaceAll(r'\n', '\n');

    final merged = <String, String>{};
    final dir = Directory('tool/i18n');
    for (final f in dir.listSync().whereType<File>()) {
      if (!RegExp(r'hi_\d+\.json$').hasMatch(f.path)) continue;
      (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>).forEach(
        (k, v) => merged[decode(k)] = decode(v as String),
      );
    }
    expect(merged.length, stringsHi.length);
    final drifted = merged.entries
        .where((e) => stringsHi[e.key] != e.value)
        .map((e) => e.key)
        .toList();
    expect(
      drifted,
      isEmpty,
      reason: 'run `python tool/i18n/generate.py`: ${drifted.join(', ')}',
    );
  });
}
