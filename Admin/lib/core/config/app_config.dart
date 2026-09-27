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

  /// Sent with every photograph fetched from the web. Wikimedia, where the
  /// parts catalogue's pictures live, answers the stock `Dart/3.x (dart:io)`
  /// agent with 429 and nothing else under its User-Agent policy, so every
  /// part tile fell back to its icon. An agent that names the app is served.
  static const Map<String, String> imageHeaders = {
    'User-Agent': 'BalajiGarageAdmin/$version ($shareBase) Flutter',
  };

  /// Where a shared job card opens. The customer taps this in a WhatsApp
  /// message and sees their own bill without installing or signing in to
  /// anything — see `supabase/07_share.sql` and the `/j/:token` route in
  /// `Website/src/pages/JobCard.jsx`.
  ///
  /// No trailing slash; [shareLink] adds the path.
  static const String shareBase = String.fromEnvironment(
    'SHARE_BASE',
    defaultValue: 'https://balajiautomobiles.in',
  );

  /// The public link for one job card's share token.
  static String shareLink(String token) => '$shareBase/j/$token';

  /// Where a customer gets the Balaji Car app — the download site. This is
  /// what the Online Garage screen shares: the customer installs the app,
  /// finds the workshop by name and books from its menu. (It used to share
  /// `my.ttngarage.com/<slug>`, a site that has never existed.)
  static const String customerAppLink = String.fromEnvironment(
    'CUSTOMER_APP_LINK',
    defaultValue: 'https://balaji-automobiles-apps.netlify.app',
  );

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
  static const String authRedirect =
      'com.garagepro.garageproadmin://login-callback';

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Where the Support sheet dials out to.
  static const String supportPhone = '9269297999';
  static const String supportWhatsapp = '919269297999';

  /// Months after a closed job card that the next service falls due.
  static const int nextServiceMonths = 6;

  /// Kilometres after a closed job card that the next service falls due.
  static const int nextServiceKm = 5000;
}
