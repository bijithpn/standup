import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/analytics/presentation/widgets/daily_budgets_card.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Map<AppCategory, int> used,
    Map<String, int> budgets,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyBudgetsCard(
              usedSecondsByCategory: used,
              budgetMinutes: budgets,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders nothing when no budget is set', (tester) async {
    await pump(tester, {AppCategory.coding: 600}, const {});
    expect(find.text('Daily budgets'), findsNothing);
  });

  testWidgets('ignores zero budgets', (tester) async {
    await pump(tester, {}, {'coding': 0});
    expect(find.text('Daily budgets'), findsNothing);
  });

  testWidgets('shows used against limit for each budgeted category', (
    tester,
  ) async {
    await pump(
      tester,
      {AppCategory.coding: 30 * 60, AppCategory.browsing: 5 * 60},
      {'coding': 120, 'browsing': 60},
    );
    expect(find.text('Daily budgets'), findsOneWidget);
    expect(find.text(AppCategory.coding.label), findsOneWidget);
    expect(find.text(AppCategory.browsing.label), findsOneWidget);
    expect(find.textContaining('over'), findsNothing);
  });

  testWidgets('flags a category that is over its budget', (tester) async {
    await pump(tester, {AppCategory.coding: 3 * 3600}, {'coding': 120});
    expect(find.textContaining('over'), findsOneWidget);
  });
}
