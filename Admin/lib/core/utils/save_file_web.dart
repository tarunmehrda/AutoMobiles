import 'dart:typed_data';

/// The browser has no writable documents directory — the caller falls back to
/// handing the bytes to the download/share path instead.
Future<String?> saveDocument(String fileName, Uint8List bytes) async => null;
