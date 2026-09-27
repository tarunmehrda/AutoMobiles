import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's illustration set, and where it came from.
///
/// ## Provenance
///
/// unDraw, by Katerina Limpitsouni — <https://undraw.co>. Pulled as SVG from
/// the mirror at <https://github.com/mkhairi/undraw> (`vendor/assets/images/
/// undraw/`), which is the same artwork the site serves.
///
/// unDraw's licence permits use in commercial and non-commercial products
/// with no attribution required. What it does not permit is redistributing
/// the collection itself as a product, or building something whose value *is*
/// the illustrations — neither of which is what a workshop console does with
/// a picture of an empty box. The credit above is therefore courtesy rather
/// than obligation, and it stays in the source where the next person to
/// wonder will look.
///
/// ## What was done to them
///
/// unDraw draws every illustration with exactly one brand colour, `#6c63ff`,
/// and that single-hex discipline is the whole reason this set is usable
/// here: substituting it for the palette's signal orange turns a stock
/// illustration into this app's illustration, and the file is otherwise
/// untouched. It is done once, at fetch time, rather than at runtime — an SVG
/// recoloured on every build is a string parse on every build.
///
/// The consequence to know about: the orange is *baked in*. A palette whose
/// accent moves has to re-run the fetch. That is the trade for not shipping a
/// colour-substitution pass into the render path, and for a workshop app
/// whose accent has been the same orange since the first commit, it is the
/// right way round.
class Art {
  const Art._();

  static const String vehicle = 'assets/images/art_vehicle.svg';
  static const String vehicleSale = 'assets/images/art_vehicle_sale.svg';
  static const String maintenance = 'assets/images/art_maintenance.svg';
  static const String empty = 'assets/images/art_empty.svg';
  static const String noData = 'assets/images/art_no_data.svg';
  static const String searching = 'assets/images/art_searching.svg';
  static const String invoice = 'assets/images/art_invoice.svg';
  static const String wallet = 'assets/images/art_wallet.svg';
  static const String done = 'assets/images/art_done.svg';
  static const String stock = 'assets/images/art_stock.svg';
  static const String customers = 'assets/images/art_customers.svg';
  static const String delivery = 'assets/images/art_delivery.svg';
}

/// One illustration, sized and placed.
///
/// A thin wrapper, but a wrapper worth having: it is the single place that
/// decides what happens when an illustration cannot be decoded, and it keeps
/// the [SvgPicture] import out of thirty call sites.
class GArt extends StatelessWidget {
  const GArt(
    this.asset, {
    super.key,
    this.height = 140,
    this.width,
    this.opacity = 1.0,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String asset;
  final double? height;
  final double? width;

  /// For artwork used as wallpaper behind text rather than as the subject.
  final double opacity;

  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      asset,
      height: height,
      width: width,
      fit: fit,
      semanticsLabel: semanticLabel,
      // A missing or malformed asset leaves a hole the size of the artwork
      // rather than throwing under a page the user is trying to read.
      placeholderBuilder: (_) => SizedBox(height: height, width: width),
    );
    if (opacity >= 1.0) return picture;
    return Opacity(opacity: opacity, child: picture);
  }
}
