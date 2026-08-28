import 'package:flutter/material.dart';


/// 暖盘风格底部弹层（component_patterns.bottom_sheet）：r28 + 遮罩 + 深棕 toast。
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget> actions;

  const AppBottomSheet({super.key, this.title, required this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
            ],
            Flexible(child: SingleChildScrollView(child: body)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x7334291A),
    builder: (_) => child,
  );
}

/// 深棕 toast（位于 TabBar 上方，样式对齐原型）。
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
}

/// 普通确认弹窗。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  String confirmText = '确认',
  String cancelText = '再想想',
  bool danger = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      content: content == null
          ? null
          : Text(content, style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: scheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 带撤销按钮的 Snackbar（软删缓冲 / 消耗撤销 5 秒窗口）。
void showUndoBar(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: duration,
      action: SnackBarAction(
        label: '撤销',
        textColor: scheme.onPrimaryContainer,
        onPressed: onUndo,
      ),
    ));
}
