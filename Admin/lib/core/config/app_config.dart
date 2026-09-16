/// Console configuration.
///
/// The admin app runs end to end on its on-device store with no backend at
/// all, exactly like the customer app. The two share a data shape, so one
/// Supabase project can back both once credentials are filled in here.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Balaji Automobiles';
  static const String tagline = 'Run the whole workshop.';
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
  static const String authRedirect = 'com.garagepro.garageproadmin://login-callback';

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Seconds an OTP stays valid.
  static const int otpTtlSeconds = 300;

  /// Seconds before "Resend OTP" is offered again.
  static const int otpResendSeconds = 30;

  /// Where the Support sheet dials out to.
  static const String supportPhone = '9269297999';
  static const String supportWhatsapp = '919269297999';

  /// Months after a closed job card that the next service falls due.
  static const int nextServiceMonths = 6;

  /// Kilometres after a closed job card that the next service falls due.
  static const int nextServiceKm = 5000;
}
