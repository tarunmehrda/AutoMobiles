/// Backend configuration.
///
/// The app runs end-to-end on its on-device store with no backend at all.
/// The moment real Supabase credentials are filled in here (or passed with
/// `--dart-define`), [SupabaseGateway] switches on and the same data is
/// mirrored to Postgres. Nothing else in the app needs to change.
library;

import '../../config/brand.dart';

class AppConfig {
  const AppConfig._();

  // Identity lives in one place so a rebrand is one file. See
  // `lib/config/brand.dart`.
  static const String appName = Brand.appName;
  static const String tagline = Brand.tagline;
  static const String version = '1.0.0';

  /// Paste the project URL here, or pass --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _supabaseUrlFallback,
  );

  /// Paste the anon/public key here, or pass --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _supabaseAnonKeyFallback,
  );

  // ---- project credentials -------------------------------------------------
  // This is the PUBLISHABLE (anon) key. It is meant to be in the client:
  // every request it makes is still filtered by row level security.
  // Never put the service_role / secret key in an app — it bypasses RLS.
  static const String _supabaseUrlFallback =
      'https://zlrmcrhwtfbwbxhfmygs.supabase.co';
  static const String _supabaseAnonKeyFallback =
      'sb_publishable_IJGQOXtE8tr7b_IgIi5cdQ_wDs6oFl7';
  // -------------------------------------------------------------------------


  /// The OAuth **Web** client from Google Cloud Console — the same one pasted
  /// into Supabase -> Authentication -> Providers -> Google. Native sign-in
  /// asks Google for an ID token addressed to this client, which is what
  /// Supabase checks the token against.
  static const String googleWebClientId =
      '787349507364-b943fq2sf47h2eqa3chiuck7923q7gv7.apps.googleusercontent.com';

  /// Where Google (and any other OAuth provider) sends the browser back
  /// to. Registered in AndroidManifest.xml and Info.plist, and must be
  /// listed under Authentication -> URL Configuration in Supabase.
  static const String authRedirect = '${Brand.androidPackage}://login-callback';

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;


  /// Garage service radius for pickup & drop.
  static const int pickupRadiusKm = 12;

  /// GST applied to every invoice.
  static const double gstRate = 0.18;
}
