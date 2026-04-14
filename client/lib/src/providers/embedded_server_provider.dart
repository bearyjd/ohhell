// Selects the correct implementation at compile time:
//   - dart.library.html  → web (no dart:io, no shelf)
//   - otherwise          → native (dart:io + shelf server)
export 'embedded_server_native.dart'
    if (dart.library.html) 'embedded_server_web.dart';
