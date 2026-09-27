import 'package:flutter/foundation.dart';

/// On the web image_picker hands back a blob URL rather than a path, and the
/// bytes are not ours to read back. The document leaves the photo block out
/// rather than printing a broken frame.
Future<Uint8List?> readImageBytes(String path) async => null;
