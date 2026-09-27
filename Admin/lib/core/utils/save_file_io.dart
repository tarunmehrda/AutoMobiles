import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _downloads = MethodChannel('garagepro/downloads');

/// Writes [bytes] into the platform's documents directory and returns where
/// it landed, so the app can tell the user rather than just claiming it
/// saved. Returns null when the platform cannot write files.
Future<String?> saveDocument(String fileName, Uint8List bytes) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    // Nowhere to write. The caller hands the bytes to the OS instead, which
    // is a better answer than an error the counter can do nothing about.
    return null;
  }
}

/// Puts [bytes] in the phone's own Downloads folder and returns where it
/// landed, or null if nowhere would take it.
///
/// Android goes through MediaStore, which needs no permission from Android 10
/// and puts the file where the Downloads app and every file manager can see
/// it. Desktop has a real downloads directory. iOS has no shared Downloads at
/// all, so the app's own documents folder — which is what the Files app shows
/// under the app's name — is the honest answer there.
Future<String?> saveToDownloads(
  String fileName,
  Uint8List bytes, {
  String mime = 'application/pdf',
}) async {
  if (Platform.isAndroid) {
    try {
      return await _downloads.invokeMethod<String>('saveToDownloads', {
        'name': fileName,
        'bytes': bytes,
        'mime': mime,
      });
    } on PlatformException {
      // Fall through to the app's own storage rather than losing the file.
    } on MissingPluginException {
      // Running against an older build of the host app.
    }
  }

  try {
    final dir = await getDownloadsDirectory();
    if (dir != null) {
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  } catch (_) {
    // Not every platform has one.
  }

  return saveDocument(fileName, bytes);
}

/// Copies a freshly picked photo into the app's own storage and returns the
/// new path.
///
/// image_picker hands back a file in the cache directory, which Android is
/// free to empty whenever it wants space. A job card's handover photos are
/// evidence months later, so they cannot live there.
Future<String> keepImage(String path) async {
  try {
    final source = File(path);
    if (!await source.exists()) return path;
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}photos',
    );
    await dir.create(recursive: true);
    final name =
        "${DateTime.now().microsecondsSinceEpoch}-${path.split(Platform.pathSeparator).last.split('/').last}";
    final kept = await source.copy('${dir.path}${Platform.pathSeparator}$name');
    return kept.path;
  } catch (_) {
    // Better the cache copy than no photo at all.
    return path;
  }
}
