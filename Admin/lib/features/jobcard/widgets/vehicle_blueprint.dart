import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/i18n/strings.dart';
import '../../../data/models/enums.dart';

/// What the damage sheet is drawn for. A job card's marks are namespaced by
/// this, so switching between them swaps the sheet and its marks together
/// rather than stranding a mark on a body it was never put on.
enum VehicleKind { twoWheeler, threeWheeler, fourWheeler, sixWheeler }

extension VehicleKindX on VehicleKind {
  String get label => switch (this) {
    VehicleKind.twoWheeler => '2-Wheeler',
    VehicleKind.threeWheeler => '3-Wheeler',
    VehicleKind.fourWheeler => '4-Wheeler',
    VehicleKind.sixWheeler => '6-Wheeler',
  };

  static VehicleKind parse(String? v) => VehicleKind.values.firstWhere(
    (e) => e.name == v,
    orElse: () => VehicleKind.fourWheeler,
  );
}

extension VehicleShapeSheet on VehicleShape {
  /// Which of these sheets a body is marked up on. One sheet per body style,
  /// so a truck is never marked up on a car.
  VehicleKind get sheet => switch (this) {
    VehicleShape.twoWheeler => VehicleKind.twoWheeler,
    VehicleShape.threeWheeler => VehicleKind.threeWheeler,
    VehicleShape.fourWheeler => VehicleKind.fourWheeler,
    VehicleShape.sixWheeler => VehicleKind.sixWheeler,
  };
}

/// One line of the drawing: SVG path data and how heavy to draw it.
@immutable
class Ink {
  const Ink(this.d, [this.weight = 1.1]);
  final String d;
  final double weight;
}

/// One orthographic view on the sheet.
///
/// [paths] is a placeholder drawing built from plain SVG path data. Point
/// [asset] at a bundled image instead and that is used verbatim — which is how
/// a proper technical drawing gets swapped in without touching any other code.
@immutable
class BlueprintView {
  const BlueprintView({
    required this.key,
    required this.label,
    required this.width,
    required this.height,
    required this.paths,
    this.halfWidth = false,
    this.asset,
  });

  final String key;
  final String label;

  /// The space [paths] are drawn in; the view is scaled to fit its box.
  final double width;
  final double height;

  final List<Ink> paths;

  /// Whether this view shares a row with the one after it, the way front and
  /// rear sit side by side.
  final bool halfWidth;

  final String? asset;

  double get aspect => width / height;
}

/// Every view of every body, keyed the way a mark stores it.
final Map<VehicleKind, List<BlueprintView>> kBlueprints = {
  VehicleKind.twoWheeler: [
    BlueprintView(
      key: 'side',
      label: 'Side'.tr,
      width: 200.0,
      height: 112.0,
      halfWidth: false,
      paths: [
        Ink('M 46 82 m -25 0 a 25 25 0 1 0 50 0 a 25 25 0 1 0 -50 0', 1.4),
        Ink('M 46 82 m -12 0 a 12 12 0 1 0 24 0 a 12 12 0 1 0 -24 0', 1.1),
        Ink('M 158 82 m -25 0 a 25 25 0 1 0 50 0 a 25 25 0 1 0 -50 0', 1.4),
        Ink('M 158 82 m -12 0 a 12 12 0 1 0 24 0 a 12 12 0 1 0 -24 0', 1.1),
        Ink('M 92 46 Q 110 36 130 42 L 140 54 L 120 60 L 96 58 Z', 1.3),
        Ink('M 56 42 L 92 44 L 96 54 L 60 56 Z', 1.3),
        Ink('M 42 32 L 58 40 L 60 54 L 46 48 Z', 1.1),
        Ink('M 100 60 L 132 60 L 136 80 L 104 82 Z', 1.3),
        Ink('M 104 76 L 50 82', 1.1),
        Ink('M 122 82 Q 96 92 68 88', 1.1),
        Ink('M 142 44 L 156 80', 1.1),
        Ink('M 150 42 L 164 78', 1.1),
        Ink('M 134 30 L 152 38', 1.1),
        Ink('M 142 24 Q 158 26 164 38 L 150 44 Z', 1.3),
        Ink('M 162 42 Q 172 44 174 50', 1.1),
        Ink('M 138 58 Q 158 48 178 60', 1.1),
        Ink('M 26 60 Q 44 50 64 56', 1.1),
        Ink('M 96 58 L 92 74', 1.1),
        Ink('M 130 60 L 138 50', 1.1),
      ],
    ),
    BlueprintView(
      key: 'top',
      label: 'Top'.tr,
      width: 200.0,
      height: 72.0,
      halfWidth: false,
      paths: [
        Ink(
          'M 40 30 L 40 42 L 66 46 Q 88 50 104 48 L 126 44 L 138 38 L 138 34 L 126 28 L 104 24 Q 88 22 66 26 Z',
          1.4,
        ),
        Ink('M 148 10 L 148 62', 1.4),
        Ink('M 142 6 L 154 6 L 154 16 L 142 16 Z', 1.1),
        Ink('M 142 56 L 154 56 L 154 66 L 142 66 Z', 1.1),
        Ink('M 154 32 L 180 32 L 180 40 L 154 40 Z', 1.3),
        Ink('M 18 32 L 40 32 L 40 40 L 18 40 Z', 1.3),
        Ink('M 144 12 L 134 4', 1.1),
        Ink('M 144 60 L 134 68', 1.1),
        Ink('M 66 26 L 66 46', 1.1),
        Ink('M 104 24 L 104 48', 1.1),
        Ink('M 138 36 L 148 36', 1.1),
      ],
    ),
    BlueprintView(
      key: 'front',
      label: 'Front'.tr,
      width: 104.0,
      height: 116.0,
      halfWidth: true,
      paths: [
        Ink('M 30 32 Q 52 18 74 32 L 78 62 Q 52 72 26 62 Z', 1.4),
        Ink('M 38 36 L 66 36 L 62 50 L 42 50 Z', 1.1),
        Ink('M 8 28 L 30 33', 1.3),
        Ink('M 96 28 L 74 33', 1.3),
        Ink('M 2 20 L 12 20 L 12 30 L 2 30 Z', 1.1),
        Ink('M 92 20 L 102 20 L 102 30 L 92 30 Z', 1.1),
        Ink('M 40 66 L 40 92', 1.1),
        Ink('M 64 66 L 64 92', 1.1),
        Ink('M 45 88 L 59 88 L 59 112 L 45 112 Z', 1.4),
        Ink('M 30 62 Q 52 70 74 62', 1.1),
      ],
    ),
    BlueprintView(
      key: 'rear',
      label: 'Rear'.tr,
      width: 104.0,
      height: 116.0,
      halfWidth: true,
      paths: [
        Ink('M 34 30 Q 52 22 70 30 L 76 50 L 28 50 Z', 1.4),
        Ink('M 41 34 L 63 34 L 61 44 L 43 44 Z', 1.1),
        Ink('M 28 50 Q 52 60 76 50', 1.3),
        Ink('M 26 58 L 78 58', 1.1),
        Ink('M 43 86 L 61 86 L 61 112 L 43 112 Z', 1.4),
        Ink('M 46 62 L 46 86', 1.1),
        Ink('M 58 62 L 58 86', 1.1),
        Ink('M 76 66 Q 90 72 88 86 L 76 86', 1.1),
        Ink('M 40 64 L 64 64 L 64 72 L 40 72 Z', 1.1),
      ],
    ),
  ],
  VehicleKind.threeWheeler: [
    BlueprintView(
      key: 'side',
      label: 'Side'.tr,
      width: 200.0,
      height: 124.0,
      halfWidth: false,
      paths: [
        Ink(
          'M 34 92 L 30 52 Q 32 26 66 20 L 124 18 Q 152 22 158 46 L 164 76 L 168 92 Z',
          1.4,
        ),
        Ink('M 150 44 Q 158 46 160 56 L 146 58 L 144 44 Z', 1.1),
        Ink('M 44 34 Q 48 28 62 26 L 96 25 L 96 56 L 42 56 Z', 1.1),
        Ink('M 102 25 L 130 26 Q 146 30 150 42 L 102 46 Z', 1.1),
        Ink('M 99 24 L 99 58', 1.1),
        Ink('M 38 58 L 158 58', 1.1),
        Ink('M 36 74 L 162 74', 1.1),
        Ink('M 56 92 m -22 0 a 22 22 0 1 0 44 0 a 22 22 0 1 0 -44 0', 1.4),
        Ink('M 56 92 m -10 0 a 10 10 0 1 0 20 0 a 10 10 0 1 0 -20 0', 1.1),
        Ink('M 166 94 m -18 0 a 18 18 0 1 0 36 0 a 18 18 0 1 0 -36 0', 1.4),
        Ink('M 166 94 m -8 0 a 8 8 0 1 0 16 0 a 8 8 0 1 0 -16 0', 1.1),
        Ink('M 30 74 A 22 22 0 0 1 82 78', 1.1),
        Ink('M 148 78 A 18 18 0 0 1 184 80', 1.1),
        Ink('M 154 40 L 166 40', 1.1),
        Ink('M 34 46 L 30 46', 1.1),
        Ink('M 60 18 L 60 26', 1.1),
      ],
    ),
    BlueprintView(
      key: 'top',
      label: 'Top'.tr,
      width: 200.0,
      height: 96.0,
      halfWidth: false,
      paths: [
        Ink(
          'M 34 24 L 140 22 Q 168 26 180 40 Q 190 48 180 56 Q 168 70 140 74 L 34 72 Q 22 66 22 48 Q 22 30 34 24 Z',
          1.4,
        ),
        Ink('M 138 30 L 160 40 L 160 56 L 138 66', 1.1),
        Ink('M 134 28 L 96 28 L 96 68 L 134 68 Z', 1.1),
        Ink('M 92 28 L 46 30 L 46 66 L 92 68 Z', 1.1),
        Ink('M 42 30 L 42 66', 1.1),
        Ink('M 176 40 L 188 44 L 188 52 L 176 56 Z', 1.1),
        Ink('M 22 34 L 12 34 L 12 44 L 22 44', 1.1),
        Ink('M 22 52 L 12 52 L 12 62 L 22 62', 1.1),
        Ink('M 160 34 L 168 26', 1.1),
        Ink('M 160 62 L 168 70', 1.1),
      ],
    ),
    BlueprintView(
      key: 'front',
      label: 'Front'.tr,
      width: 112.0,
      height: 124.0,
      halfWidth: true,
      paths: [
        Ink(
          'M 18 88 L 14 46 Q 18 22 40 18 L 72 18 Q 94 22 98 46 L 94 88 Z',
          1.4,
        ),
        Ink('M 26 44 Q 30 26 44 24 L 68 24 Q 82 26 86 44 Z', 1.1),
        Ink('M 20 56 L 92 56', 1.1),
        Ink('M 46 60 Q 56 54 66 60 L 68 76 L 44 76 Z', 1.1),
        Ink('M 22 62 L 34 62 L 34 72 L 22 72 Z', 1.1),
        Ink('M 90 62 L 78 62 L 78 72 L 90 72 Z', 1.1),
        Ink('M 20 80 L 92 80', 1.1),
        Ink('M 50 88 L 62 88 L 62 114 L 50 114 Z', 1.4),
        Ink('M 56 24 L 56 18', 1.1),
      ],
    ),
    BlueprintView(
      key: 'rear',
      label: 'Rear'.tr,
      width: 112.0,
      height: 124.0,
      halfWidth: true,
      paths: [
        Ink(
          'M 14 92 L 12 46 Q 16 22 40 18 L 72 18 Q 96 22 100 46 L 98 92 Z',
          1.4,
        ),
        Ink('M 22 46 Q 26 26 42 24 L 70 24 Q 86 26 90 46 Z', 1.1),
        Ink('M 16 56 L 96 56', 1.1),
        Ink('M 18 62 L 32 62 L 32 74 L 18 74 Z', 1.1),
        Ink('M 94 62 L 80 62 L 80 74 L 94 74 Z', 1.1),
        Ink('M 44 64 L 68 64 L 68 76 L 44 76 Z', 1.1),
        Ink('M 16 82 L 96 82', 1.1),
        Ink('M 20 92 L 34 92 L 34 116 L 20 116 Z', 1.4),
        Ink('M 78 92 L 92 92 L 92 116 L 78 116 Z', 1.4),
      ],
    ),
  ],
  VehicleKind.fourWheeler: [
    BlueprintView(
      key: 'side',
      label: 'Side'.tr,
      width: 200.0,
      height: 84.0,
      halfWidth: false,
      paths: [
        Ink(
          'M 10 60 L 9 46 Q 9 38 18 36 L 56 34 L 76 16 L 126 16 L 148 33 L 180 36 Q 192 39 193 49 L 193 60 Z',
          1.4,
        ),
        Ink('M 26 60 A 16 16 0 0 1 58 60', 1.1),
        Ink('M 140 60 A 16 16 0 0 1 172 60', 1.1),
        Ink('M 42 62 m -15 0 a 15 15 0 1 0 30 0 a 15 15 0 1 0 -30 0', 1.1),
        Ink('M 42 62 m -7 0 a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0', 1.1),
        Ink('M 156 62 m -15 0 a 15 15 0 1 0 30 0 a 15 15 0 1 0 -30 0', 1.1),
        Ink('M 156 62 m -7 0 a 7 7 0 1 0 14 0 a 7 7 0 1 0 -14 0', 1.1),
        Ink('M 62 33 L 80 19 L 98 19 L 98 33 Z', 1.1),
        Ink('M 104 33 L 104 19 L 122 19 L 138 33 Z', 1.1),
        Ink('M 101 33 L 101 58', 1.1),
        Ink('M 62 34 L 62 57', 1.1),
        Ink('M 140 34 L 140 57', 1.1),
        Ink('M 88 40 L 96 40', 1.1),
        Ink('M 108 40 L 116 40', 1.1),
        Ink('M 60 55 L 140 55', 1.1),
        Ink('M 176 41 Q 186 41 191 45', 1.1),
        Ink('M 11 43 L 23 44', 1.1),
        Ink('M 24 60 L 12 60', 1.1),
        Ink('M 176 60 L 190 60', 1.1),
      ],
    ),
    BlueprintView(
      key: 'top',
      label: 'Top'.tr,
      width: 200.0,
      height: 92.0,
      halfWidth: false,
      paths: [
        Ink(
          'M 16 32 Q 16 21 30 18 L 62 15 L 136 14 Q 166 16 182 25 Q 193 32 193 46 Q 193 60 182 67 Q 166 76 136 78 L 62 77 L 30 74 Q 16 71 16 60 Z',
          1.4,
        ),
        Ink('M 136 22 L 114 29 L 114 63 L 136 70 Z', 1.1),
        Ink('M 76 29 L 114 29 L 114 63 L 76 63 Z', 1.1),
        Ink('M 56 22 L 76 29 L 76 63 L 56 70 Z', 1.1),
        Ink('M 139 19 L 139 73', 1.1),
        Ink('M 53 19 L 53 73', 1.1),
        Ink('M 137 16 L 148 13 L 149 19 L 138 21 Z', 1.1),
        Ink('M 137 76 L 148 79 L 149 73 L 138 71 Z', 1.1),
        Ink('M 168 24 Q 180 28 185 34', 1.1),
        Ink('M 168 68 Q 180 64 185 58', 1.1),
        Ink('M 24 30 L 24 62', 1.1),
      ],
    ),
    BlueprintView(
      key: 'front',
      label: 'Front'.tr,
      width: 120.0,
      height: 92.0,
      halfWidth: true,
      paths: [
        Ink(
          'M 14 74 L 11 46 Q 13 31 26 28 L 36 15 L 84 15 L 94 28 Q 107 31 109 46 L 106 74 Z',
          1.4,
        ),
        Ink('M 36 28 L 42 18 L 78 18 L 84 28 Z', 1.1),
        Ink('M 40 52 L 80 52 L 80 60 L 40 60 Z', 1.1),
        Ink('M 16 44 L 36 42 L 36 50 L 17 50 Z', 1.1),
        Ink('M 104 44 L 84 42 L 84 50 L 103 50 Z', 1.1),
        Ink('M 13 64 L 107 64', 1.1),
        Ink('M 50 66 L 70 66 L 70 72 L 50 72 Z', 1.1),
        Ink('M 14 74 L 14 84', 1.1),
        Ink('M 106 74 L 106 84', 1.1),
        Ink('M 26 30 L 94 30', 1.1),
      ],
    ),
    BlueprintView(
      key: 'rear',
      label: 'Rear'.tr,
      width: 120.0,
      height: 92.0,
      halfWidth: true,
      paths: [
        Ink(
          'M 14 74 L 12 46 Q 13 32 26 29 L 34 16 L 86 16 L 94 29 Q 107 32 108 46 L 106 74 Z',
          1.4,
        ),
        Ink('M 34 29 L 40 19 L 80 19 L 86 29 Z', 1.1),
        Ink('M 16 42 L 38 40 L 38 52 L 17 52 Z', 1.1),
        Ink('M 104 42 L 82 40 L 82 52 L 103 52 Z', 1.1),
        Ink('M 13 62 L 107 62', 1.1),
        Ink('M 44 50 L 76 50 L 76 58 L 44 58 Z', 1.1),
        Ink('M 14 74 L 14 84', 1.1),
        Ink('M 106 74 L 106 84', 1.1),
        Ink('M 26 31 L 94 31', 1.1),
      ],
    ),
  ],
  VehicleKind.sixWheeler: [
    BlueprintView(
      key: 'side',
      label: 'Side'.tr,
      width: 200.0,
      height: 96.0,
      halfWidth: false,
      paths: [
        Ink('M 12 68 L 10 38 Q 10 28 20 26 L 31 12 L 62 12 L 62 68 Z', 1.4),
        Ink('M 66 68 L 66 14 L 190 14 L 190 68 Z', 1.4),
        Ink('M 62 68 L 66 68', 1.1),
        Ink('M 12 72 L 190 72', 1.4),
        Ink('M 36 26 L 40 16 L 58 16 L 58 26 Z', 1.1),
        Ink('M 40 30 L 60 30 L 60 64 L 40 64 Z', 1.1),
        Ink('M 44 42 L 51 42', 1.1),
        Ink('M 14 34 L 30 34 L 30 44 L 14 44 Z', 1.1),
        Ink('M 11 48 L 23 48 L 23 56 L 12 56 Z', 1.1),
        Ink('M 10 60 L 30 60', 1.1),
        Ink('M 31 18 L 24 14 L 24 25 L 31 23', 1.1),
        Ink('M 36 78 m -14 0 a 14 14 0 1 0 28 0 a 14 14 0 1 0 -28 0', 1.4),
        Ink('M 36 78 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0', 1.1),
        Ink('M 150 78 m -14 0 a 14 14 0 1 0 28 0 a 14 14 0 1 0 -28 0', 1.4),
        Ink('M 150 78 m -6 0 a 6 6 0 1 0 12 0 a 6 6 0 1 0 -12 0', 1.1),
        Ink('M 22 72 A 14 14 0 0 1 50 74', 1.1),
        Ink('M 136 72 A 14 14 0 0 1 164 74', 1.1),
        Ink('M 66 38 L 190 38', 1.1),
        Ink('M 104 14 L 104 68', 1.1),
        Ink('M 142 14 L 142 68', 1.1),
        Ink('M 74 72 L 74 84 L 98 84 L 98 72', 1.3),
        Ink('M 172 68 L 172 80 L 188 80 L 188 68', 1.1),
      ],
    ),
    BlueprintView(
      key: 'top',
      label: 'Top'.tr,
      width: 200.0,
      height: 84.0,
      halfWidth: false,
      paths: [
        Ink(
          'M 16 12 L 190 12 L 190 72 L 16 72 Q 8 60 8 42 Q 8 24 16 12 Z',
          1.4,
        ),
        Ink('M 62 12 L 62 72', 1.4),
        Ink('M 20 20 L 56 20 L 56 64 L 20 64 Z', 1.1),
        Ink('M 70 18 L 184 18 L 184 66 L 70 66 Z', 1.1),
        Ink('M 112 18 L 112 66', 1.1),
        Ink('M 148 18 L 148 66', 1.1),
        Ink('M 14 8 L 28 3 L 30 8 L 17 13', 1.1),
        Ink('M 14 76 L 28 81 L 30 76 L 17 71', 1.1),
        Ink('M 10 30 L 10 54', 1.1),
        Ink('M 38 20 L 38 64', 1.1),
      ],
    ),
    BlueprintView(
      key: 'front',
      label: 'Front'.tr,
      width: 120.0,
      height: 104.0,
      halfWidth: true,
      paths: [
        Ink(
          'M 12 86 L 10 24 Q 10 14 22 12 L 98 12 Q 110 14 110 24 L 108 86 Z',
          1.4,
        ),
        Ink('M 18 20 L 102 20 L 102 44 L 18 44 Z', 1.1),
        Ink('M 28 52 L 92 52 L 92 66 L 28 66 Z', 1.3),
        Ink('M 34 56 L 86 56', 1.1),
        Ink('M 34 61 L 86 61', 1.1),
        Ink('M 11 54 L 25 54 L 25 66 L 12 66 Z', 1.1),
        Ink('M 109 54 L 95 54 L 95 66 L 108 66 Z', 1.1),
        Ink('M 10 70 L 110 70 L 110 84 L 10 84 Z', 1.3),
        Ink('M 46 72 L 74 72 L 74 82 L 46 82 Z', 1.1),
        Ink('M 10 22 L 2 18 L 2 36 L 10 33', 1.1),
        Ink('M 110 22 L 118 18 L 118 36 L 110 33', 1.1),
        Ink('M 26 42 L 46 26', 1.1),
        Ink('M 62 42 L 82 26', 1.1),
        Ink('M 20 88 L 34 88 L 34 100 L 20 100 Z', 1.4),
        Ink('M 86 88 L 100 88 L 100 100 L 86 100 Z', 1.4),
      ],
    ),
    BlueprintView(
      key: 'rear',
      label: 'Rear'.tr,
      width: 120.0,
      height: 104.0,
      halfWidth: true,
      paths: [
        Ink('M 10 82 L 10 10 L 110 10 L 110 82 Z', 1.4),
        Ink('M 60 10 L 60 82', 1.1),
        Ink('M 14 60 L 28 60 L 28 76 L 14 76 Z', 1.1),
        Ink('M 106 60 L 92 60 L 92 76 L 106 76 Z', 1.1),
        Ink('M 46 62 L 74 62 L 74 74 L 46 74 Z', 1.1),
        Ink('M 12 84 L 108 84', 1.3),
        Ink('M 12 20 L 22 20', 1.1),
        Ink('M 12 48 L 22 48', 1.1),
        Ink('M 98 20 L 108 20', 1.1),
        Ink('M 98 48 L 108 48', 1.1),
        Ink('M 52 30 L 68 30 L 68 46 L 52 46 Z', 1.1),
        Ink('M 20 86 L 34 86 L 34 100 L 20 100 Z', 1.4),
        Ink('M 86 86 L 100 86 L 100 100 L 86 100 Z', 1.4),
        Ink('M 36 86 L 46 86 L 46 100 L 36 100 Z', 1.1),
        Ink('M 74 86 L 84 86 L 84 100 L 74 100 Z', 1.1),
      ],
    ),
  ],
};

/// How a mark records which drawing it belongs to, e.g. `fourWheeler.side`.
String viewId(VehicleKind kind, BlueprintView view) =>
    '${kind.name}.${view.key}';

/// Draws one view's line art, scaled to fill the box it is given.
class BlueprintPainter extends CustomPainter {
  BlueprintPainter({required this.view, required this.line});

  final BlueprintView view;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / view.width;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final ink in view.paths) {
      canvas.drawPath(parseSvgPathData(ink.d), paint..strokeWidth = ink.weight);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BlueprintPainter old) =>
      old.view != view || old.line != line;
}
