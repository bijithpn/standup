import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/analytics/presentation/widgets/category_budgets_card.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  late Map<String, int> budgets;
  late int hours;

  Future<void> pump(WidgetTester tester, int office, Map<String, int> initial) {
    budgets = initial;
    hours = office;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: CategoryBudgetsCard(
                officeHours: hours,
                onOfficeHoursChanged: (v) => setState(() => hours = v),
                budgetMinutes: budgets,
                onChanged: (v) => setState(() => budgets = v),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();
  }

  final coding = AppCategory.coding.label;
  final writing = AppCategory.writing.label;

  testWidgets('budgets stop at the office hours', (tester) async {
    await pump(tester, 1, {'coding': 50});

    await tap(tester, 'Increase $writing budget');
    expect(budgets['writing'], 10);

    await tap(tester, 'Increase $coding budget');
    expect(budgets['coding'], 50);
    expect(find.text('0m left to budget'), findsOneWidget);
  });

  testWidgets('office hours cannot drop below what is budgeted', (
    tester,
  ) async {
    await pump(tester, 2, {'coding': 75});

    await tap(tester, 'Decrease office hours');
    expect(hours, 2);

    await tap(tester, 'Decrease $coding budget');
    await tap(tester, 'Decrease office hours');
    expect(hours, 1);
  });

  testWidgets('an over-allocated day can only be lowered', (tester) async {
    await pump(tester, 1, {'coding': 90});
    expect(find.textContaining('over. Lower a budget'), findsOneWidget);

    await tap(tester, 'Increase $coding budget');
    expect(budgets['coding'], 90);

    await tap(tester, 'Decrease $coding budget');
    expect(budgets['coding'], 75);
  });
}
