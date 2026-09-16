import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes [bytes] into the platform's documents directory and returns where
/// it landed, so the console can tell the user rather than just claiming it
/// saved. Returns null when the platform cannot write files.
Future<String?> saveDocument(String fileName, Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
