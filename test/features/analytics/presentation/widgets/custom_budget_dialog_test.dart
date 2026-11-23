import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/analytics/presentation/widgets/custom_budget_dialog.dart';
import 'package:breakmate/features/settings/custom_budget_category.dart';

void main() {
  testWidgets('creates a type with a searched icon and a typed app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CustomBudgetCategory? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showCustomBudgetDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Social, Reading, Gaming'),
      'Gaming',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Search icons'),
      'game',
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('game controller'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search or type an app name'),
      'Steam',
    );
    await tester.pump();
    await tester.tap(find.text('Add "Steam"'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Gaming');
    expect(result?.appNames, ['Steam']);
    expect(kBudgetIconSet[result!.iconIndex].$2, 'game controller');
  });
}
