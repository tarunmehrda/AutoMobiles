import 'app_language.dart';
import 'strings_hi.dart';

/// The console's copy, looked up by its English source text.
///
/// There is no code-generation step and no key catalogue to keep in sync:
/// the English string in the widget *is* the key. A screen reads the same
/// whether or not it has been translated yet, and a missing entry falls
/// through to the English it was written with rather than showing a key or
/// throwing — so a half-finished translation degrades into English instead
/// of into a broken screen.
///
/// The language is held statically rather than on an inherited widget
/// because most of this app's copy is built by `const` widgets, which never
/// rebuild for an inherited change. [AppShell] keys the whole navigator on
/// the language instead, so a switch rebuilds everything exactly once.
class Tr {
  const Tr._();

  static AppLanguage _language = AppLanguage.en;

  static AppLanguage get language => _language;

  /// Swaps the dictionary. Callers are responsible for rebuilding the tree —
  /// see `localeProvider` and the shell's [ValueKey].
  static void use(AppLanguage language) => _language = language;

  static Map<String, String> get _table =>
      _language == AppLanguage.hi ? stringsHi : const {};

  /// The translation of [source], or [source] itself when there is none.
  static String of(String source) => _table[source] ?? source;

  /// The translation of a `{0}`-style template with [args] substituted.
  ///
  /// Positional placeholders rather than inline interpolation so a
  /// translation can reorder them — Hindi puts the verb last, and several
  /// of these read backwards if the parts are locked in English order.
  static String fill(String template, List<Object?> args) {
    var out = _table[template] ?? template;
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', '${args[i]}');
    }
    return out;
  }

  /// Picks between a singular and a plural template, then fills it.
  ///
  /// Hindi and English agree on "one versus the rest", which is all this
  /// app's counters need; anything finer would want real CLDR plural rules.
  static String plural(
    int count,
    String one,
    String many, [
    List<Object?> args = const [],
  ]) => fill(count == 1 ? one : many, args.isEmpty ? [count] : args);
}

extension TrX on String {
  /// `'Job cards'.tr` — the translation of this literal.
  String get tr => Tr.of(this);

  /// `'{0} recorded'.trf([amount])` — a template with its arguments.
  String trf(List<Object?> args) => Tr.fill(this, args);
}
