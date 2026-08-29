import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warmpantry/widgets/app_feedback.dart';

/// 消耗反馈回归：清零自动归档会卸载调用点 widget（mounted=false），
/// await 前缓存的 ScaffoldMessenger 必须仍能弹出 toast / 撤销条（T011 真机缺陷）。
void main() {
  // 挂载一个按钮，tap 后执行 onTap 并立刻把按钮所在子树拆掉，模拟
  // 「数据变更 → 调用点 widget 卸载」；onTap 在 await 后再调反馈函数。
  Future<void> bootAndUnmount(
    WidgetTester tester,
    void Function(BuildContext, ScaffoldMessengerState) onTap,
  ) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: messengerKey,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ));
    final messenger = ScaffoldMessenger.of(capturedContext);
    // 换掉整棵子树：capturedContext 已失效，等价于 widget 卸载后的 mounted=false
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: messengerKey,
      home: Scaffold(body: Container()),
    ));
    await tester.pump();
    onTap(capturedContext, messenger);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('widget 卸载后 showUndoBarOn 仍显示，5 秒自动关闭', (tester) async {
    await bootAndUnmount(tester, (context, messenger) {
      expect(context.mounted, isFalse); // 前置：调用点确已失效
      showUndoBarOn(messenger, '已消耗 1 件', onUndo: () {});
    });
    expect(find.text('已消耗 1 件'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);
    // 小步推进：5 秒 timer 触发关闭后，退出动画需要多帧走完
    for (var t = 0; t < 8; t++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('已消耗 1 件'), findsNothing);
  });

  testWidgets('widget 卸载后 showToastOn 仍显示', (tester) async {
    await bootAndUnmount(tester, (context, messenger) {
      showToastOn(messenger, '已记录 −1 件');
    });
    expect(find.text('已记录 −1 件'), findsOneWidget);
  });

  testWidgets('context 版 showUndoBar 在 mounted 后正常显示并自动关闭', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  showUndoBar(context, '已移出 2 件物品', onUndo: () {}),
              child: const Text('tap'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('tap'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已移出 2 件物品'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);
    // 小步推进：5 秒 timer 触发关闭后，退出动画需要多帧走完
    for (var t = 0; t < 8; t++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('已移出 2 件物品'), findsNothing);
  });
}
