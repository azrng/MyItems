import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/models.dart';

void main() {
  group('Expiry status', () {
    test('formats date with mainland China style', () {
      expect(formatDate(DateTime(2026, 5, 9)), '2026年5月9日');
    });

    test('classifies expired expiring safe and no-expiry items', () {
      final today = DateTime(2026, 5, 9);

      expect(calculateExpiryStatus(DateTime(2026, 5, 8), today), ExpiryStatus.expired);
      expect(calculateExpiryStatus(DateTime(2026, 5, 16), today), ExpiryStatus.expiring);
      expect(calculateExpiryStatus(DateTime(2026, 5, 17), today), ExpiryStatus.safe);
      expect(calculateExpiryStatus(null, today), ExpiryStatus.noExpiry);
    });

    test('formats visible expiry status text', () {
      final today = DateTime(2026, 5, 9);

      expect(getExpiryStatusText(ExpiryStatus.expired, DateTime(2026, 5, 6), today), '过期 3 天');
      expect(getExpiryStatusText(ExpiryStatus.expiring, DateTime(2026, 5, 11), today), '临期 2 天');
      expect(getExpiryStatusText(ExpiryStatus.safe, DateTime(2026, 6, 1), today), '');
      expect(getExpiryStatusText(ExpiryStatus.noExpiry, null, today), '');
    });
  });

  group('Item display', () {
    test('calculates daily cost from purchase date', () {
      final today = DateTime(2026, 5, 9);
      final display = ItemDisplay.fromItem(
        item: Item(
          id: '1',
          name: '牛奶',
          categoryId: 'food',
          purchaseDate: DateTime(2026, 5, 4),
          purchasePrice: 20,
          expiryDate: DateTime(2026, 5, 12),
          quantity: 2,
          createdAt: today,
          updatedAt: today,
        ),
        category: Category(id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
        today: today,
      );

      expect(display.holdingDays, 5);
      expect(display.dailyCost, 4);
      expect(display.dailyCostText, '¥4.00/天');
    });

    test('matches keyword against name brand category and location', () {
      final today = DateTime(2026, 5, 9);
      final display = ItemDisplay.fromItem(
        item: Item(
          id: '1',
          name: '酸奶',
          categoryId: 'food',
          brand: '伊利',
          defaultLocation: '冰箱上层',
          createdAt: today,
          updatedAt: today,
        ),
        category: Category(id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
        today: today,
      );

      expect(display.matchesKeyword('酸'), isTrue);
      expect(display.matchesKeyword('伊利'), isTrue);
      expect(display.matchesKeyword('食品'), isTrue);
      expect(display.matchesKeyword('冰箱'), isTrue);
      expect(display.matchesKeyword('药箱'), isFalse);
    });
  });
}
