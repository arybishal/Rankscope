import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rankscope/app.dart';

void main() {
  testWidgets('RankScopeApp mounts and renders navigation shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RankScopeApp()));

    // Initial pump and settle
    await tester.pump();

    // Verify RankScope header is present
    expect(find.text('RankScope'), findsWidgets);

    // Verify Bottom Navigation tabs are present
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('SERP Audit'), findsOneWidget);
    expect(find.text('GSC'), findsOneWidget);
    expect(find.text('Bing'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
