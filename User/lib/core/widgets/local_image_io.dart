import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a picked image from a device file path.
Widget localImage(
  String path, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
  required Widget Function() fallback,
}) {
  return Image.file(
    File(path),
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (_, _, _) => fallback(),
  );
}
