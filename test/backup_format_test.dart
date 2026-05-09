import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/models.dart';
import 'package:my_items/repository.dart';

void main() {
  test('builds complete backup payload with all migration tables', () {
    final exportedAt = DateTime(2026, 5, 9, 16, 30);
    final itemCreatedAt = DateTime(2026, 5, 9, 10);
    final itemUpdatedAt = DateTime(2026, 5, 9, 11);
    final consumedAt = DateTime(2026, 5, 9, 12);

    final payload = buildBackupPayload(
      categories: const [
        Category(
          id: 'food',
          name: '食品/饮料',
          icon: '🍔',
          sortOrder: 1,
          isPreset: true,
        ),
      ],
      locations: const [
        StorageLocation(id: 'fridge', name: '冰箱', sortOrder: 1),
      ],
      items: [
        Item(
          id: 'milk',
          name: '牛奶',
          categoryId: 'food',
          defaultLocation: '冰箱',
          purchasePrice: 6.8,
          quantity: 4,
          initialQuantity: 4,
          remainingQuantity: 3,
          trackDailyCost: true,
          createdAt: itemCreatedAt,
          updatedAt: itemUpdatedAt,
        ),
      ],
      consumptionRecords: [
        ConsumptionRecord(
          id: 'record-1',
          itemId: 'milk',
          quantity: 1,
          type: ConsumptionType.consumeOne,
          consumedAt: consumedAt,
        ),
      ],
      settings: const {'theme_preference': 'dark'},
      exportedAt: exportedAt,
    );

    expect(payload['format'], myItemsBackupFormat);
    expect(payload['schemaVersion'], 2);
    expect(payload['exportedAt'], exportedAt.toIso8601String());
    expect(payload['categories'], hasLength(1));
    expect(payload['locations'], hasLength(1));
    expect(payload['items'], hasLength(1));
    expect(payload['consumptionRecords'], hasLength(1));
    expect(payload['settings'], {'theme_preference': 'dark'});
  });

  test('parses complete backup payload back to typed records', () {
    final payload = {
      'format': myItemsBackupFormat,
      'schemaVersion': 2,
      'exportedAt': '2026-05-09T16:30:00.000',
      'categories': [
        {
          'id': 'food',
          'name': '食品/饮料',
          'icon': '🍔',
          'sort_order': 1,
          'is_preset': 1,
          'is_active': 1,
        }
      ],
      'locations': [
        {
          'id': 'fridge',
          'name': '冰箱',
          'sort_order': 1,
          'is_active': 1,
        }
      ],
      'items': [
        {
          'id': 'milk',
          'name': '牛奶',
          'category_id': 'food',
          'default_location': '冰箱',
          'is_archived': 0,
          'purchase_price': 6.8,
          'quantity': 4,
          'initial_quantity': 4,
          'remaining_quantity': 3,
          'track_daily_cost': 1,
          'created_at': '2026-05-09T10:00:00.000',
          'updated_at': '2026-05-09T11:00:00.000',
        }
      ],
      'consumptionRecords': [
        {
          'id': 'record-1',
          'item_id': 'milk',
          'quantity': 1,
          'type': 'consume_one',
          'consumed_at': '2026-05-09T12:00:00.000',
        }
      ],
      'settings': {'theme_preference': 'dark'},
    };

    final backup = parseBackupPayload(payload);

    expect(backup.categories.single.name, '食品/饮料');
    expect(backup.locations.single.name, '冰箱');
    expect(backup.items.single.remainingQuantity, 3);
    expect(backup.consumptionRecords.single.type, ConsumptionType.consumeOne);
    expect(backup.settings['theme_preference'], 'dark');
  });
}
