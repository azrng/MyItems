import 'package:flutter_test/flutter_test.dart';
import 'package:warmpantry/core/utils/expiry_helper.dart';

void main() {
  final now = DateTime(2026, 8, 28, 10, 0);

  group('ExpiryHelper.effectiveExpiry（§3.2 有效到期日）', () {
    test('两者都有取较早者', () {
      final eff = ExpiryHelper.effectiveExpiry(
        expiryDate: DateTime(2026, 9, 10),
        openedAt: DateTime(2026, 8, 20),
        openShelfLifeDays: 4,
      );
      expect(eff, DateTime(2026, 8, 24));
    });

    test('仅有保质期', () {
      expect(
        ExpiryHelper.effectiveExpiry(expiryDate: DateTime(2026, 9, 10)),
        DateTime(2026, 9, 10),
      );
    });

    test('仅有开封限期', () {
      expect(
        ExpiryHelper.effectiveExpiry(
            openedAt: DateTime(2026, 8, 20), openShelfLifeDays: 7),
        DateTime(2026, 8, 27),
      );
    });

    test('都为空返回 null（无期限）', () {
      expect(ExpiryHelper.effectiveExpiry(), isNull);
    });
  });

  group('ExpiryHelper.statusOf（§4.1 分级）', () {
    DateTime daysFromNow(int d) => now.add(Duration(days: d));

    test('已过期', () {
      expect(
        ExpiryHelper.statusOf(
            effectiveExpiryDate: daysFromNow(-1), now: now, warningDays: 3),
        ExpiryStatus.expired,
      );
    });

    test('24 小时内（今天/明天）为 urgent', () {
      for (final d in [0, 1]) {
        expect(
          ExpiryHelper.statusOf(
              effectiveExpiryDate: daysFromNow(d), now: now, warningDays: 3),
          ExpiryStatus.urgent,
          reason: '+$d 天应为 urgent',
        );
      }
    });

    test('预警天数受设置影响（3/5/7）', () {
      // +4 天：默认 3 天档是 attention，5 天档是 warning
      expect(
        ExpiryHelper.statusOf(
            effectiveExpiryDate: daysFromNow(4), now: now, warningDays: 3),
        ExpiryStatus.attention,
      );
      expect(
        ExpiryHelper.statusOf(
            effectiveExpiryDate: daysFromNow(4), now: now, warningDays: 5),
        ExpiryStatus.warning,
      );
    });

    test('注意（≤7 天）与安全', () {
      expect(
        ExpiryHelper.statusOf(
            effectiveExpiryDate: daysFromNow(7), now: now, warningDays: 3),
        ExpiryStatus.attention,
      );
      expect(
        ExpiryHelper.statusOf(
            effectiveExpiryDate: daysFromNow(8), now: now, warningDays: 3),
        ExpiryStatus.safe,
      );
    });

    test('无期限', () {
      expect(
        ExpiryHelper.statusOf(
            effectiveExpiryDate: null, now: now, warningDays: 3),
        ExpiryStatus.none,
      );
    });
  });

  group('ExpiryHelper 开封标签（§4.2）', () {
    test('未开封', () {
      expect(ExpiryHelper.openedLabel(), '未开封');
    });

    test('开封第 N 天', () {
      expect(
        ExpiryHelper.openedLabel(
            openedAt: now.subtract(const Duration(days: 1)), now: now),
        '开封第 2 天',
      );
    });

    test('PAO 按月展示', () {
      expect(
        ExpiryHelper.openedLabel(
            openedAt: now.subtract(const Duration(days: 150)),
            openShelfLifeDays: 180,
            now: now),
        '开封满 6 个月（PAO）',
      );
    });
  });

  group('ExpiryHelper 余量（§4.3 低余量阈值）', () {
    test('百分比计算', () {
      expect(ExpiryHelper.remainingPercent(6.5, 10), 65);
      expect(ExpiryHelper.remainingPercent(0, 10), 0);
      expect(ExpiryHelper.remainingPercent(12, 10), 100);
    });

    test('低余量判定（默认 25%，可选 20/25/30）', () {
      expect(ExpiryHelper.isLowRemaining(2.5, 10, 25), isTrue);
      expect(ExpiryHelper.isLowRemaining(2.6, 10, 25), isFalse);
      expect(ExpiryHelper.isLowRemaining(3.0, 10, 30), isTrue);
      expect(ExpiryHelper.isLowRemaining(2.0, 10, 20), isTrue);
    });
  });

  group('ExpiryHelper 开封超限', () {
    test('超限判定', () {
      expect(
        ExpiryHelper.isOpenOverdue(
          openedAt: now.subtract(const Duration(days: 6)),
          openShelfLifeDays: 4,
          now: now,
        ),
        isTrue,
      );
      expect(
        ExpiryHelper.isOpenOverdue(
          openedAt: now.subtract(const Duration(days: 2)),
          openShelfLifeDays: 4,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
