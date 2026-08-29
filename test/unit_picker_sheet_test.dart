import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warmpantry/features/editor/unit_picker_sheet.dart';

void main() {
  testWidgets('单位选择弹层渲染常用单位并可选择', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                picked = await showUnitPickerSheet(context, current: '袋');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('计量单位'), findsOneWidget);
    expect(find.text('盒'), findsOneWidget);
    expect(find.text('袋'), findsOneWidget, reason: '当前单位应高亮显示');

    await tester.tap(find.text('盒'));
    await tester.pumpAndSettle();
    expect(picked, '盒');
  });
}
