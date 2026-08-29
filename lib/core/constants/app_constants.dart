/// 全局常量：预置数据、阈值档位、常用单位、设置键名。
/// 对齐 requirement.md §3.9 / §3.10 / §3.7 / §4.1 / §4.9。
library;

/// 设置键名（settings 表 KV）
class SettingKeys {
  static const themeMode = 'theme_mode';
  static const nickname = 'nickname';
  static const expiryWarningDays = 'expiry_warning_days';
  static const lowRemainingPercent = 'low_remaining_percent';
  static const dailySummaryEnabled = 'daily_summary_enabled';
  static const summaryHour = 'summary_hour';
  static const summaryMinute = 'summary_minute';
  static const autoBackupEnabled = 'auto_backup_enabled';
  static const backupKeepCount = 'backup_keep_count';
  static const lastBackupAt = 'last_backup_at';
  static const lastBackupSize = 'last_backup_size';
  static const lastBackupOk = 'last_backup_ok';
  static const lastBackupError = 'last_backup_error';
  static const onboardingDone = 'onboarding_done';
  static const lastUsedUnit = 'last_used_unit';
  static const bellReadDate = 'bell_read_date';
  static const draft = 'draft';
  static const pendingDeletes = 'pending_deletes';
  // 坚果云 WebDAV 同步（§7.2；应用密码存 settings 表，仅应用私有目录可见）
  static const cloudSyncUrl = 'cloud_sync_url';
  static const cloudSyncUser = 'cloud_sync_user';
  static const cloudSyncToken = 'cloud_sync_token';
  static const cloudSyncKeepCount = 'cloud_sync_keep_count';
  static const cloudSyncAutoPush = 'cloud_sync_auto_push';
  static const cloudSyncLastAt = 'cloud_sync_last_at';
  static const cloudSyncLastOk = 'cloud_sync_last_ok';
  static const cloudSyncLastError = 'cloud_sync_last_error';
}

/// 默认设置值
class SettingDefaults {
  static const nickname = '小暖';
  static const expiryWarningDays = 3;
  static const lowRemainingPercent = 25;
  static const summaryHour = 8;
  static const summaryMinute = 30;
  static const backupKeepCount = 5;
  static const cloudSyncUrl = 'https://dav.jianguoyun.com/dav/';
  static const cloudSyncKeepCount = 5;
}

/// 阈值档位（我的 → 提醒设置弹层可调）
class ThresholdChoices {
  static const expiryWarningDays = [3, 5, 7];
  static const lowRemainingPercent = [20, 25, 30];
}

/// 预置分类（requirement.md §3.9，共 8 个）
class PresetCategories {
  static const List<({String name, String icon, String description, String colorKey, int sortOrder})> all = [
    (name: '食品食材', icon: '🥕', description: '含生鲜 / 零食 / 冲调', colorKey: 'olive', sortOrder: 1),
    (name: '日用清洁', icon: '🧹', description: '洗衣 / 厨卫清洁用品', colorKey: 'teal', sortOrder: 2),
    (name: '厨房小物', icon: '🍳', description: '保鲜袋 / 锡纸 / 百洁布', colorKey: 'gold', sortOrder: 3),
    (name: '药品保健', icon: '💊', description: 'OTC / 维生素 / 医疗器械', colorKey: 'rose', sortOrder: 4),
    (name: '美妆护肤', icon: '💄', description: '含开封后有效期追踪', colorKey: 'violet', sortOrder: 5),
    (name: '酒水饮料', icon: '🧃', description: '咖啡 / 茶 / 饮品囤货', colorKey: 'accent', sortOrder: 6),
    (name: '数码周边', icon: '🔌', description: '电池 / 数据线 / 存储卡', colorKey: 'ink', sortOrder: 7),
    (name: '其他杂物', icon: '📦', description: '暂未归类的物品', colorKey: 'gold', sortOrder: 8),
  ];
}

/// 预置存储位置（requirement.md §3.10，区域 → 位置两级）
class PresetLocations {
  static const List<({String region, String name, String icon, int? capacity})> all = [
    (region: '🏠 厨房区域', name: '冰箱冷藏室', icon: '🧊', capacity: 10),
    (region: '🏠 厨房区域', name: '冰箱冷冻室', icon: '❄️', capacity: 10),
    (region: '🏠 厨房区域', name: '橱柜吊柜', icon: '🗄️', capacity: null),
    (region: '🏠 厨房区域', name: '调料架', icon: '🧂', capacity: null),
    (region: '🚿 卫生间区域', name: '镜柜', icon: '🪞', capacity: null),
    (region: '🚿 卫生间区域', name: '洗手台下方柜', icon: '🧴', capacity: null),
    (region: '🛋 居住区域', name: '玄关收纳柜', icon: '👟', capacity: null),
    (region: '🛋 居住区域', name: '书桌抽屉', icon: '🗃️', capacity: null),
  ];

  static const presetRegions = ['🏠 厨房区域', '🚿 卫生间区域', '🛋 居住区域'];
}

/// 常用计量单位 chips（requirement.md §5.6）
class CommonUnits {
  static const all = ['袋', '盒', '瓶', '罐', '包', '片', '粒', '支', '张', '卷', 'ml', 'L', 'g', 'kg'];
}

/// 分类颜色 key（design-system tokens.colors 分类色系）
class CategoryColorKeys {
  static const all = ['olive', 'rose', 'teal', 'violet', 'gold', 'accent'];
}

/// 流水类型 / 来源（requirement.md §3.5）
class LogTypes {
  static const intake = 'intake';
  static const open = 'open';
  static const consume = 'consume';
  static const archive = 'archive';
  static const adjust = 'adjust';
}

class LogSources {
  static const manual = '手动录入';
  static const quickConsume = '快捷消耗';
  static const quickIntake = '快捷再入库';
  static const repurchase = '再买一次';
  static const adjust = '余量校正';
}

/// 归档筛选 chips（requirement.md §5.10）
class ArchiveFilterChips {
  static const all = ['本月', '食品', '日化', '药品', '值得回购 ⭐'];
}

/// 撤销窗口（软删缓冲 / 消耗撤销，requirement.md §4.8 / §3.5）
class UndoWindows {
  static const snackbarMs = 5000;
  static const deleteDebounce = Duration(seconds: 5);
  static const backupDebounce = Duration(seconds: 30);
}
