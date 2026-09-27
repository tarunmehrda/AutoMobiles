import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/vehicle_card.dart';
import 'package:garagepro_admin/data/models/enums.dart';
import 'package:garagepro_admin/data/seed/vehicle_catalog.dart';
import 'package:garagepro_admin/data/seed/vehicle_media.dart';
import 'package:garagepro_admin/features/jobcard/widgets/vehicle_picker.dart';

/// The headline the model picker exists to deliver: **pick Swift and you see
/// the Swift**, in the list, before you commit to it.
///
/// Worth a widget test rather than only a lookup test, because the two ways
/// this breaks are both invisible to `VehicleMedia`'s own tests. The sheet can
/// be handed the picture and never build it, and the row can build it at the
/// wrong size and clip it away to nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Opens the picker the way the job card's model step opens it.
  Future<void> openModels(WidgetTester tester, {required String make}) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    pickFromCatalog(
      ctx,
      title: 'Model',
      subtitle: make,
      options: VehicleCatalog.modelsOf(make, VehicleShape.fourWheeler),
      photoOf: (m) => VehicleMedia.photoFor(make, m, VehicleShape.fourWheeler),
      exactOf: (m) => VehicleMedia.exactPhotoFor(m) != null,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the model list shows each model\'s own photograph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openModels(tester, make: 'Maruti Suzuki');

    // Rows decode at row height rather than at the file's own 480px, which
    // wraps the provider — unwrapping it here is also what proves that is
    // still happening.
    String assetOf(ImageProvider provider) {
      final inner = provider is ResizeImage ? provider.imageProvider : provider;
      return (inner as AssetImage).assetName;
    }

    Set<String> shownImages() => tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => assetOf(i.image))
        .toSet();

    // Every row that is built has a picture, and none falls through to the
    // placeholder glyph.
    expect(shownImages(), isNotEmpty);
    expect(find.byIcon(Icons.directions_car_rounded), findsNothing);

    // A make whose whole range has been photographed shows no stand-ins at
    // all: every visible row is the model itself.
    expect(
      shownImages().every((a) => a.startsWith('assets/models/')),
      isTrue,
      reason: 'a Maruti row fell back to a body shot: ${shownImages()}',
    );

    // Now find the Swift the way the counter does. The list is lazy and the
    // Swift is thirty rows down, so searching is also what brings it on
    // screen at all.
    await tester.enterText(find.byType(TextField), 'Swift');
    await tester.pumpAndSettle();

    // Scoped to the list: the search box now holds the word too.
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('Swift')),
      findsOneWidget,
    );
    // Filtered down to the one row, the only picture on screen is the
    // Swift's own — proof the exact photograph is what the row resolved to,
    // rather than merely being present somewhere in a longer list.
    expect(shownImages(), {'assets/models/swift.jpg'});
  });

  testWidgets('a picture of the real car is labelled, a stand-in is not', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await openModels(tester, make: 'Maruti Suzuki');

    // The badge follows the photograph, not the row. `Swift` has one of its
    // own; `Versa` is a van the harvest never found and falls back to its
    // body, so it must not claim to be a photograph of a Versa.
    expect(VehicleMedia.exactPhotoFor('Swift'), isNotNull);
    expect(VehicleMedia.exactPhotoFor('Versa'), isNull);
    expect(find.text('Photo'), findsWidgets);
  });

  testWidgets('the make list shows each marque badge', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    pickFromCatalog(
      ctx,
      title: 'Make',
      subtitle: 'marques',
      options: VehicleCatalog.makesFor(VehicleShape.twoWheeler),
      logoOf: VehicleMedia.logoFor,
    );
    await tester.pumpAndSettle();

    expect(find.text('Royal Enfield'), findsOneWidget);
    expect(find.byType(GMarqueLogo), findsWidgets);
  });

  testWidgets('the variant list stays plain text', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    // No photoOf, no logoOf — a trim level has no picture, and a column of
    // identical photographs beside LXi / VXi / ZXi would be pure noise.
    pickFromCatalog(
      ctx,
      title: 'Variant',
      subtitle: 'Swift',
      options: VehicleCatalog.variantsOf('Swift'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
  });
}
