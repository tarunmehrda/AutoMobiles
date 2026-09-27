import 'dart:typed_data';

/// The web has no file system to write to — the caller falls back to handing
/// the bytes to the browser.
Future<String?> saveDocument(String fileName, Uint8List bytes) async => null;

/// See the io implementation. On the web the browser's own download is the
/// only route, so this reports that it did not save.
Future<String?> saveToDownloads(
  String fileName,
  Uint8List bytes, {
  String mime = 'application/pdf',
}) async =>
    null;
