import 'package:drift/drift.dart' hide Batch;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../database/app_database.dart';
import '../repositories/inventory_repository.dart';

/// 预置数据写入（requirement.md §3.9 / §3.10 / §5.14）。
/// 首启引导写入；恢复备份后按同名补齐缺失预置。
class SeedService {
  final InventoryRepository repo;
  SeedService(this.repo);

  /// 写入 8 个预置分类；locations 同时决定是否写入 8 个预置位置。
  Future<void> seed({required bool withPresetLocations}) async {
    final existing = await repo.getCategories();
    final existingNames = existing.map((e) => e.name).toSet();
    for (final c in PresetCategories.all) {
      if (existingNames.contains(c.name)) continue;
      await repo.insertCategory(CategoriesCompanion.insert(
        id: newId(),
        name: c.name,
        description: Value(c.description),
        icon: Value(c.icon),
        colorKey: Value(c.colorKey),
        sortOrder: Value(c.sortOrder),
        isPreset: const Value(true),
      ));
    }
    if (!withPresetLocations) return;
    final locations = await repo.getLocations();
    final existingLocNames = locations.map((e) => e.name).toSet();
    var order = 0;
    for (final l in PresetLocations.all) {
      order++;
      if (existingLocNames.contains(l.name)) continue;
      await repo.insertLocation(StorageLocationsCompanion.insert(
        id: newId(),
        name: l.name,
        region: Value(l.region),
        icon: Value(l.icon),
        capacity: Value(l.capacity),
        sortOrder: Value(order),
        isActive: const Value(true),
      ));
    }
  }
}
