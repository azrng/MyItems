import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../providers/inventory_providers.dart';
import '../../data/models/view_models.dart';

/// 物品库筛选 / 排序 / 多选状态（页面本地 UI 状态，StateProvider 承载）。

final searchQueryProvider = StateProvider<String>((ref) => '');

/// null = 全部分类
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// null = 全部位置
final selectedLocationProvider = StateProvider<String?>((ref) => null);

/// 0 = 到期时间升序（默认），1 = 添加时间倒序
final sortModeProvider = StateProvider<int>((ref) => 0);

final selectModeProvider = StateProvider<bool>((ref) => false);

final selectedIdsProvider = StateProvider<Set<String>>((ref) => {});

/// 筛选 + 排序后的物品视图。
final filteredLibraryViewsProvider = Provider<List<LibraryItemView>>((ref) {
  final views = ref.watch(activeViewsProvider);
  final query = ref.watch(searchQueryProvider).trim();
  final categoryId = ref.watch(selectedCategoryProvider);
  final locationId = ref.watch(selectedLocationProvider);
  final sortMode = ref.watch(sortModeProvider);
  final locations = ref.watch(locationsProvider).value ?? const <StorageLocation>[];

  Iterable<LibraryItemView> result = views;
  if (categoryId != null) {
    result = result.where((v) => v.item.categoryId == categoryId);
  }
  if (locationId != null) {
    result = result.where((v) =>
        v.activeBatches.any((b) => b.locationId == locationId));
  }
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    final locNameById = {for (final l in locations) l.id: l.name};
    result = result.where((v) {
      final inName = v.item.name.toLowerCase().contains(q);
      final inSpec = (v.item.spec ?? '').toLowerCase().contains(q);
      final batchNotes = v.activeBatches
          .any((b) => (b.notes ?? '').toLowerCase().contains(q));
      final inLocation = v.activeBatches
          .any((b) => (locNameById[b.locationId] ?? '').toLowerCase().contains(q));
      return inName || inSpec || batchNotes || inLocation;
    });
  }
  final list = result.toList();
  if (sortMode == 0) {
    double key(LibraryItemView v) =>
        v.effectiveExpiry?.millisecondsSinceEpoch.toDouble() ?? double.maxFinite;
    list.sort((a, b) => key(a).compareTo(key(b)));
  } else {
    list.sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));
  }
  return list;
});
