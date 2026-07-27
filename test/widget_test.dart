import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inventario_video_app/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: InventarioVideoApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Inventario Video'), findsWidgets);
  });
}
