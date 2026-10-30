import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/shared/widgets/cards/ranking_badge.dart';

void main() {
  group('RankingBadge Widget', () {
    testWidgets('renders unranked state when position is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RankingBadge(position: null))),
      );

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('renders position and positive delta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RankingBadge(position: 3, delta: 2)),
        ),
      );

      expect(find.text('#3'), findsOneWidget);
      expect(find.text('▲2'), findsOneWidget);
    });

    testWidgets('renders negative delta correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RankingBadge(position: 8, delta: -4)),
        ),
      );

      expect(find.text('#8'), findsOneWidget);
      expect(find.text('▼4'), findsOneWidget);
    });
  });
}
