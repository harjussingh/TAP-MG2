import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> saveFile(String name, Uint8List bytes, String mimeType) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  // Give the browser a moment to start the download before releasing the blob.
  Future.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
  return 'Downloaded $name';
}
