import 'dart:typed_data';

import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart' as impl;

/// Saves [bytes] as a file the user can open. On the web this triggers a browser download.
/// Returns a short description of where the file went.
Future<String> saveFile(String name, Uint8List bytes, String mimeType) => impl.saveFile(name, bytes, mimeType);
