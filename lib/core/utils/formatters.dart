import 'dart:math';

/// ID 生成（无网络依赖的 UUID v4 风格字符串）。
String newId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int i) => b.sublist(i, i + 1).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  String seg(int from, int to) => [for (var i = from; i < to; i++) hex(i)].join();
  return '${seg(0, 4)}-${seg(4, 6)}-${seg(6, 8)}-${seg(8, 10)}-${seg(10, 16)}';
}

/// 日期与数量格式化（requirement.md 界面文案口径）。
class Fmt {
  Fmt._();

  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String shortDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// 头部日期「周一 · 8月27日」
  static String headerDate(DateTime d) => '${weekday(d)} · ${d.month}月${d.day}日';

  /// 相对时间：今天 09:12 / 昨天 20:45 / 08-20
  static String relative(DateTime d, DateTime now) {
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return '今天 ${time(d)}';
    if (day == today.subtract(const Duration(days: 1))) return '昨天 ${time(d)}';
    return shortDate(d);
  }

  /// 日分组标题：今天 / 昨天 / 周日 / 3月12日
  static String dayGroup(DateTime d, DateTime now) {
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return '今天';
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final diff = today.difference(day).inDays;
    if (diff < 7 && d.weekday <= now.weekday) return names[d.weekday - 1];
    return '${d.month}月${d.day}日';
  }

  /// 数量展示：整数不带小数点，小数保留最多 2 位（如 12 / 0.5 / 7.25）
  static String quantity(double v) {
    if (v == v.roundToDouble()) {
      return v.round().toString();
    }
    var s = v.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  /// 文件大小
  static String bytes(int b) {
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  static String clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 时段问候（requirement.md §5.2）
  static String greeting(DateTime now) {
    if (now.hour < 6) return '这么晚还在整理呀，记得睡';
    if (now.hour < 11) return '早呀';
    if (now.hour < 18) return '你好';
    return '晚上好';
  }
}
