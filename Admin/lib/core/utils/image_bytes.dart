/// Reading a picked photo back off the device, chosen per platform at compile
/// time so the console still builds for the web (where `dart:io` does not
/// exist).
library;

export 'image_bytes_io.dart'
    if (dart.library.js_interop) 'image_bytes_web.dart';
