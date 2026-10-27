/// Everything that changes when this app is sold to another garage.
///
/// The customer-app half of the pair. It must stay in step with
/// `Admin/lib/config/brand.dart`: the two apps are one product to the person
/// holding the phone, and a colour that matches in one and not the other
/// reads as a fake.
///
/// To rebrand: change the values here, drop new art into `assets/logo/`,
/// change the Android `applicationId` and the iOS bundle id, and ship.
/// See `docs/03-rebranding.md`.
library;

import 'package:flutter/material.dart';

class Brand {
  const Brand._();

  // ---------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------

  /// What the app calls itself inside the app.
  static const String appName = 'Balaji Automobiles';

  /// The full display name on the store listing.
  static const String storeName = 'Balaji Automobiles — My Car';

  /// What fits under the launcher icon.
  static const String launcherName = 'Balaji Car';

  /// Shown under the logo on splash and sign-in.
  static const String tagline = 'Your car. Our care.';

  static const String vendor = 'Techifyhouse';

  /// The live values are in `android/app/build.gradle.kts` and
  /// `ios/Runner.xcodeproj`; recorded here so a rebrand knows where to look.
  static const String androidPackage = 'com.balajiautomobiles.customer';
  static const String iosBundleId = 'com.balajiautomobiles.customer';

  /// The workshop console this app talks to.
  static const String adminAndroidPackage = 'com.balajiautomobiles.garage';

  static const List<String> alternateProductNames = [
    'Garage Mitra',
    'MotorCare',
    'GarageEase',
  ];

  // ---------------------------------------------------------------------
  // Art
  // ---------------------------------------------------------------------

  /// The full emblem, used exactly as supplied; drawn for a dark ground, so
  /// both slots hold the same file. [logoBadge] is the
  /// same mark pre-composited on its carbon tile, for anything generated
  /// outside the app. Painted through `BrandArt` in `core/widgets/`.
  static const String logoMarkLight = 'assets/logo/mark_light.png';
  static const String logoMarkDark = 'assets/logo/mark_dark.png';
  static const String logoBadge = 'assets/logo/icon.png';

  // ---------------------------------------------------------------------
  // Colour — must match the console exactly.
  // ---------------------------------------------------------------------

  static const Color accent = Color(0xFFFF5F2E);
  static const Color accentInk = Color(0xFFD9410F);
  static const Color accentSoft = Color(0xFFFFEDE5);
  static const Color onAccent = Color(0xFFFFFFFF);

  static const List<Color> accentGradient = [
    Color(0xFFFF7A3D),
    Color(0xFFF2481B),
  ];

  static const Color seed = accent;

  // ---------------------------------------------------------------------
  // Contact
  // ---------------------------------------------------------------------

  static const String supportPhone = '9269297999';
  static const String supportWhatsapp = '919269297999';
  static const String supportEmail = 'support@balajiautomobiles.in';

  // ---------------------------------------------------------------------
  // Feature switches
  // ---------------------------------------------------------------------

  /// Pay the balance by UPI from inside the app.
  static const bool showUpiPayment = true;

  /// Message thread with the workshop.
  static const bool showChat = true;

  /// Request pickup and drop with a booking.
  static const bool showPickupDrop = true;

  /// Offers the workshop publishes.
  static const bool showOffers = true;
}
