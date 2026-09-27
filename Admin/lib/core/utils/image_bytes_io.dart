import 'dart:io';

import 'package:flutter/foundation.dart';

/// Reads a photo the counter attached to a job card, for embedding in a
/// document.
///
/// Returns null rather than throwing when the file has gone — a photo taken
/// three months ago can be deleted from under the app, and a missing picture
/// must never be the reason a bill will not print.
Future<Uint8List?> readImageBytes(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}
