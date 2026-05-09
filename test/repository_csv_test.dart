import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/repository.dart';

void main() {
  test('parses legacy csv item rows with old price and quantity fields', () {
    final header = [
      'type',
      'id',
      'name',
      'category_id',
      'icon',
      'brand',
      'location',
      'price',
      'expiry_date',
      'quantity',
      'notes',
    ];
    final row = [
      'item',
      'bread',
      '面包',
      'food',
      '🍞',
      '面包房',
      '厨房',
      '3.5',
      '2026-05-12T00:00:00.000',
      '2',
      '冷藏保存',
    ];

    final item = itemFromCsvRow(row, header, DateTime(2026, 5, 9));

    expect(item.id, 'bread');
    expect(item.name, '面包');
    expect(item.brand, '面包房');
    expect(item.defaultLocation, '厨房');
    expect(item.purchasePrice, 3.5);
    expect(item.expiryDate, DateTime(2026, 5, 12));
    expect(item.initialQuantity, 2);
    expect(item.remainingQuantity, 2);
    expect(item.notes, '冷藏保存');
    expect(item.barcode, isNull);
  });

  test('parses current csv item rows with unit price and remaining quantity', () {
    final header = [
      'type',
      'id',
      'name',
      'category_id',
      'icon',
      'barcode',
      'brand',
      'location',
      'unit_price',
      'purchase_date',
      'expiry_date',
      'initial_quantity',
      'remaining_quantity',
      'track_daily_cost',
      'notes',
      'created_at',
      'updated_at',
      'is_archived',
    ];
    final row = [
      'item',
      'milk',
      '牛奶',
      'food',
      '🥛',
      '6900001',
      '本地牧场',
      '冰箱',
      '6.8',
      '2026-05-08T00:00:00.000',
      '2026-05-15T00:00:00.000',
      '4',
      '3',
      '1',
      '开封后尽快喝完',
      '2026-05-09T10:00:00.000',
      '2026-05-09T11:00:00.000',
      '0',
    ];

    final item = itemFromCsvRow(row, header, DateTime(2026, 5, 9));

    expect(item.id, 'milk');
    expect(item.barcode, '6900001');
    expect(item.purchasePrice, 6.8);
    expect(item.purchaseDate, DateTime(2026, 5, 8));
    expect(item.initialQuantity, 4);
    expect(item.remainingQuantity, 3);
    expect(item.trackDailyCost, isTrue);
    expect(item.isArchived, isFalse);
    expect(item.createdAt, DateTime(2026, 5, 9, 10));
    expect(item.updatedAt, DateTime(2026, 5, 9, 11));
  });
}
