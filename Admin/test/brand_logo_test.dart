import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/core/theme/app_theme.dart';
import 'package:garagepro_admin/core/widgets/brand_logo.dart';

/// The mark ships in two inks, and the whole point is that the app picks
/// the right one by itself. These check the choice, not the pixels.
void main() {
  Widget host(Widget child, {required bool dark}) => MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  String assetOf(WidgetTester tester) {
    // Every use passes `cacheWidth`, which wraps the provider in a
    // ResizeImage, so the AssetImage is one layer down.
    var provider = tester.widget<Image>(find.byType(Image)).image;
    if (provider is ResizeImage) provider = provider.imageProvider;
    return (provider as AssetImage).assetName;
  }

  group('the mark', () {
    testWidgets('inks itself for the surface it lands on', (tester) async {
      await tester.pumpWidget(host(const BrandMark(), dark: false));
      await tester.pumpAndSettle();
      expect(assetOf(tester), BrandArt.markLight);

      await tester.pumpWidget(host(const BrandMark(), dark: true));
      // MaterialApp cross-fades one theme into the other, so a single
      // frame after the swap still reads as the old brightness.
      await tester.pumpAndSettle();
      expect(assetOf(tester), BrandArt.markDark);
    });

    testWidgets('takes the override over the theme', (tester) async {
      // The splash and the sign-in sheet are carbon whatever the theme is.
      await tester.pumpWidget(host(const BrandMark(onDark: true), dark: false));
      await tester.pumpAndSettle();
      expect(assetOf(tester), BrandArt.markDark);
    });
  });

  group('the badge', () {
    testWidgets('sits on the carbon plate in either theme', (tester) async {
      // The mark's white wordmark vanishes on a paper well, so the tile
      // never follows the theme.
      for (final dark in [false, true]) {
        await tester.pumpWidget(host(const BrandBadge(), dark: dark));
        await tester.pumpAndSettle();
        expect(assetOf(tester), BrandArt.markDark);
        final box = tester.widget<Container>(find.byType(Container).first);
        expect((box.decoration as BoxDecoration).color, BrandArt.carbon);
      }
    });
  });

  group('the lockup', () {
    testWidgets('is the mark alone — the name is in the artwork', (tester) async {
      await tester.pumpWidget(host(const BrandLogo(width: 240), dark: true));
      await tester.pumpAndSettle();
      expect(assetOf(tester), BrandArt.markDark);
      expect(find.text('BALAJI AUTOMOBILES'), findsNothing);
    });
  });

  test('both inks are on disk and declared', () {
    for (final a in [BrandArt.markLight, BrandArt.markDark, BrandArt.badge]) {
      expect(File(a).existsSync(), isTrue, reason: '$a is missing');
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/logo/'));
  });

  test('the launcher icon is cut at every density', () {
    const res = 'android/app/src/main/res';
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final n in [
        'ic_launcher.png',
        'ic_launcher_round.png',
        'ic_launcher_foreground.png',
      ]) {
        expect(
          File('$res/mipmap-$d/$n').existsSync(),
          isTrue,
          reason: 'mipmap-$d/$n is missing',
        );
      }
      expect(
        File('$res/drawable-$d/splash_logo.png').existsSync(),
        isTrue,
        reason: 'drawable-$d/splash_logo.png is missing',
      );
    }
  });

  test('the iOS app icon is cut at every size', () {
    const set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    for (final n in [
      'Icon-App-20x20@1x.png',
      'Icon-App-60x60@3x.png',
      'Icon-App-83.5x83.5@2x.png',
      'Icon-App-1024x1024@1x.png',
    ]) {
      expect(File('$set/$n').existsSync(), isTrue, reason: '$n is missing');
    }
  });
}
