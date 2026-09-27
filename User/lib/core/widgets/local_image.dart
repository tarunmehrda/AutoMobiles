library;

// Picked-image rendering, chosen per platform at compile time so the app
/// still builds for the web (where `dart:io` does not exist).
export 'local_image_io.dart'
    if (dart.library.js_interop) 'local_image_web.dart';
