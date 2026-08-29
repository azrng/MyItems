import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../widgets/app_feedback.dart';

/// 计量单位选择弹层（§5.6）：常用单位 chips + 自定义输入，返回所选单位。
Future<String?> showUnitPickerSheet(
  BuildContext context, {
  required String current,
}) {
  final customCtrl = TextEditingController();
  String selected = current;

  return showAppSheet<String>(
    context,
    child: AppBottomSheet(
      title: '计量单位',
      body: StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in CommonUnits.all)
                  ChoiceChip(
                    label: Text(u),
                    selected: selected == u,
                    onSelected: (_) => Navigator.pop(context, u),
                  ),
                if (!CommonUnits.all.contains(selected))
                  ChoiceChip(
                    label: Text(selected),
                    selected: true,
                    onSelected: (_) => Navigator.pop(context, selected),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: customCtrl,
              decoration: const InputDecoration(
                labelText: '自定义单位',
                hintText: '如 滴 / 喷',
              ),
              onSubmitted: (v) {
                final unit = v.trim();
                if (unit.isNotEmpty) Navigator.pop(context, unit);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final unit = customCtrl.text.trim();
                if (unit.isNotEmpty) Navigator.pop(context, unit);
              },
              child: const Text('使用自定义单位'),
            ),
          ],
        ),
      ),
    ),
  );
}
