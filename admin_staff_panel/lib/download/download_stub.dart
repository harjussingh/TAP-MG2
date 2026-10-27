import 'dart:io';
import 'dart:typed_data';

Future<String> saveFile(String name, Uint8List bytes, String mimeType) async {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.systemTemp.path;
  final dir = Directory('$home${Platform.pathSeparator}Downloads');
  final target = dir.existsSync() ? dir : Directory.systemTemp;
  final file = File('${target.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes);
  return 'Saved to ${file.path}';
}
