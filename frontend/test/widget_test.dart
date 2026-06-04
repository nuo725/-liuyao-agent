// Basic widget test for Zhouyi App
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhouyi_app/main.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: ZhouyiApp(),
      ),
    );
    // Let splash timers complete to avoid pending Timer invariant failures.
    await tester.pump(const Duration(seconds: 4));

    // Verify the app starts
    expect(find.byType(ZhouyiApp), findsOneWidget);
  });
}
