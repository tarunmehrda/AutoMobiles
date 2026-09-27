import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a picked image from a device file path — or, once the photo has
/// been uploaded, from its storage URL, which is what every other phone and
/// the customer see.
Widget localImage(
  String path, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
  required Widget Function() fallback,
}) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(
      path,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, _, _) => fallback(),
    );
  }
  return Image.file(
    File(path),
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (_, _, _) => fallback(),
  );
}
