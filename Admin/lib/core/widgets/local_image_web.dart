import 'package:flutter/material.dart';

/// On the web, image_picker hands back a blob URL rather than a file path.
Widget localImage(
  String path, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
  required Widget Function() fallback,
}) {
  return Image.network(
    path,
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (_, _, _) => fallback(),
  );
}
