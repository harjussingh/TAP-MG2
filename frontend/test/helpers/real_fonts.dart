import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flutter's default test font draws every glyph as a full-width square, so text
/// measures far wider than on a phone and layout checks report overflows that
/// never happen. This loads Roboto from the Flutter SDK under the family names
/// the app asks for (Google Fonts' Inter_400, Inter_700, ...). Roboto is close
/// to Inter's width; 600 uses Roboto Bold so the check errs on the wide side.
Future<void> loadRealFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final root = Platform.environment['FLUTTER_ROOT'] ?? _flutterRootFromPath();
  if (root == null) return; // Fall back to the test font rather than fail.
  final dir = '$root/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  const regular = 'roboto-regular.ttf',
      medium = 'roboto-medium.ttf',
      bold = 'roboto-bold.ttf';
  await load('Roboto', [regular, medium, bold]);
  for (final w in ['regular', '400']) {
    await load('Inter_$w', [regular]);
  }
  await load('Inter_500', [medium]);
  await load('Inter_600', [bold]);
  await load('Inter_700', [bold]);
  await load('Inter_800', ['roboto-black.ttf']);
  await load('Inter_900', ['roboto-black.ttf']);
}

/// `flutter test` sets FLUTTER_ROOT; this is only a fallback for other runners.
String? _flutterRootFromPath() {
  for (final p in (Platform.environment['PATH'] ?? '')
      .split(Platform.isWindows ? ';' : ':')) {
    final candidate = Directory(p).parent.path;
    if (File('$candidate/bin/cache/artifacts/material_fonts/roboto-regular.ttf')
        .existsSync()) {
      return candidate;
    }
  }
  return null;
}
