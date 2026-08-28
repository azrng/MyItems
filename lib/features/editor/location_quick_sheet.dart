import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../providers/actions.dart';
import '../../widgets/app_feedback.dart';

/// 录入页「➕ 新增位置」就地建位弹层（§5.6），返回新位置 id。
Future<String?> showLocationQuickSheet(BuildContext context) async {
  final nameCtrl = TextEditingController();
  String region = PresetLocations.presetRegions.first;
  String icon = '📦';
  final form = GlobalKey<FormState>();

  final id = await showAppSheet<String>(
    context,
    child: AppBottomSheet(
      title: '新增存放位置',
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '位置名称'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
            ),
            const SizedBox(height: 12),
            const Text('所属区域',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            StatefulBuilder(
              builder: (context, setState) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in PresetLocations.presetRegions)
                    ChoiceChip(
                      label: Text(r),
                      selected: region == r,
                      onSelected: (_) => setState(() => region = r),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('图标',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            StatefulBuilder(
              builder: (context, setState) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in ['📦', '🧊', '❄️', '🗄️', '🧂', '🪞', '🧴', '👟', '🗃️', '🪟'])
                    InkWell(
                      onTap: () => setState(() => icon = e),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: icon == e
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: icon == e
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 17)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            final container = ProviderScope.containerOf(context);
            final newIdValue = newId();
            await container.read(inventoryActionsProvider).saveLocation(
                  id: null,
                  name: nameCtrl.text.trim(),
                  region: region,
                  icon: icon,
                  capacity: null,
                  sortOrder: 99,
                  isActive: true,
                );
            if (context.mounted) Navigator.pop(context, newIdValue);
          },
          child: const Text('创建并选用'),
        ),
      ],
    ),
  );
  return id;
}
