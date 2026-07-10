import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Renders the app's brand mark (tomato rounded square + white restaurant_menu
// glyph) and writes it to assets/icon/*.png, so the launcher icon uses the
// exact widget rather than a hand-drawn approximation.
//
// Run: flutter test test/export_icon_test.dart
// Then: dart run flutter_launcher_icons

const _tomato = Color(0xFFF04E37);

/// The MaterialIcons font isn't loaded in `flutter test` by default (icons
/// render as a notdef box), so load the SDK's font before rendering.
Future<void> _loadIconFont() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (root != null)
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    r'C:\Users\theki\develop\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  ];
  final path = candidates.firstWhere((p) => File(p).existsSync());
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  late Uint8List bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

Future<void> _pumpAt1024(WidgetTester tester, GlobalKey key, Widget child) async {
  await _loadIconFont();
  tester.view.physicalSize = const Size(1024, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: key, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('export full launcher icon', (tester) async {
    final key = GlobalKey();
    await _pumpAt1024(
      tester,
      key,
      const ColoredBox(
        color: Color(0x00000000),
        child: Center(
          child: SizedBox(
            width: 896,
            height: 896,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _tomato,
                borderRadius: BorderRadius.all(Radius.circular(210)),
              ),
              child: Center(
                child: Icon(Icons.restaurant_menu_rounded,
                    color: Colors.white, size: 448),
              ),
            ),
          ),
        ),
      ),
    );
    await _capture(tester, key, 'assets/icon/sizzle_icon.png');
  });

  testWidgets('export adaptive foreground', (tester) async {
    final key = GlobalKey();
    await _pumpAt1024(
      tester,
      key,
      const Center(
        child: Icon(Icons.restaurant_menu_rounded,
            color: Colors.white, size: 470),
      ),
    );
    await _capture(tester, key, 'assets/icon/sizzle_fg.png');
  });
}
