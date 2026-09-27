/// Writing a generated document to disk, chosen per platform at compile time
/// so the console still builds for the web (where `dart:io` does not exist).
library;

export 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
