import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'core_providers.dart';

/// 设置快照（settings 表的内存投影，类型化访问）。
class SettingsState {
  final ThemeMode themeMode;
  final String nickname;
  final int expiryWarningDays;
  final int lowRemainingPercent;
  final bool dailySummaryEnabled;
  final int summaryHour;
  final int summaryMinute;
  final bool autoBackupEnabled;
  final int backupKeepCount;
  final DateTime? lastBackupAt;
  final int? lastBackupSize;
  final bool lastBackupOk;
  final String lastBackupError;
  final bool onboardingDone;
  final String? lastUsedUnit;
  final DateTime? bellReadDate;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.nickname = SettingDefaults.nickname,
    this.expiryWarningDays = SettingDefaults.expiryWarningDays,
    this.lowRemainingPercent = SettingDefaults.lowRemainingPercent,
    this.dailySummaryEnabled = true,
    this.summaryHour = SettingDefaults.summaryHour,
    this.summaryMinute = SettingDefaults.summaryMinute,
    this.autoBackupEnabled = true,
    this.backupKeepCount = SettingDefaults.backupKeepCount,
    this.lastBackupAt,
    this.lastBackupSize,
    this.lastBackupOk = true,
    this.lastBackupError = '',
    this.onboardingDone = false,
    this.lastUsedUnit,
    this.bellReadDate,
  });

  SettingsState copyWith({
    ThemeMode? themeMode, String? nickname, int? expiryWarningDays,
    int? lowRemainingPercent, bool? dailySummaryEnabled, int? summaryHour,
    int? summaryMinute, bool? autoBackupEnabled, int? backupKeepCount,
    DateTime? lastBackupAt, int? lastBackupSize, bool? lastBackupOk,
    String? lastBackupError, bool? onboardingDone, String? lastUsedUnit,
    DateTime? bellReadDate, bool clearBellRead = false,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      nickname: nickname ?? this.nickname,
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      lowRemainingPercent: lowRemainingPercent ?? this.lowRemainingPercent,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      summaryHour: summaryHour ?? this.summaryHour,
      summaryMinute: summaryMinute ?? this.summaryMinute,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupKeepCount: backupKeepCount ?? this.backupKeepCount,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastBackupSize: lastBackupSize ?? this.lastBackupSize,
      lastBackupOk: lastBackupOk ?? this.lastBackupOk,
      lastBackupError: lastBackupError ?? this.lastBackupError,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      lastUsedUnit: lastUsedUnit ?? this.lastUsedUnit,
      bellReadDate: clearBellRead ? null : (bellReadDate ?? this.bellReadDate),
    );
  }
}

String _themeModeName(ThemeMode m) =>
    m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system';

/// 设置控制器：写穿 KV 并广播。
class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    ref.watch(settingsSeedProvider); // 初始值由 main() 注入
    return ref.read(settingsSeedProvider);
  }

  Future<void> _write(Map<String, String> entries) async {
    await ref.read(inventoryRepositoryProvider).setSettings(entries);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _write({SettingKeys.themeMode: _themeModeName(mode)});
  }

  Future<void> setNickname(String nickname) async {
    final n = nickname.trim().isEmpty ? SettingDefaults.nickname : nickname.trim();
    state = state.copyWith(nickname: n);
    await _write({SettingKeys.nickname: n});
  }

  Future<void> setWarningDays(int days) async {
    state = state.copyWith(expiryWarningDays: days);
    await _write({SettingKeys.expiryWarningDays: '$days'});
  }

  Future<void> setLowRemaining(int percent) async {
    state = state.copyWith(lowRemainingPercent: percent);
    await _write({SettingKeys.lowRemainingPercent: '$percent'});
  }

  Future<void> setSummary({bool? enabled, int? hour, int? minute}) async {
    state = state.copyWith(
      dailySummaryEnabled: enabled ?? state.dailySummaryEnabled,
      summaryHour: hour ?? state.summaryHour,
      summaryMinute: minute ?? state.summaryMinute,
    );
    await _write({
      SettingKeys.dailySummaryEnabled: state.dailySummaryEnabled ? '1' : '0',
      SettingKeys.summaryHour: '${state.summaryHour}',
      SettingKeys.summaryMinute: '${state.summaryMinute}',
    });
  }

  Future<void> setAutoBackup({bool? enabled, int? keepCount}) async {
    state = state.copyWith(
      autoBackupEnabled: enabled ?? state.autoBackupEnabled,
      backupKeepCount: keepCount ?? state.backupKeepCount,
    );
    await _write({
      SettingKeys.autoBackupEnabled: state.autoBackupEnabled ? '1' : '0',
      SettingKeys.backupKeepCount: '${state.backupKeepCount}',
    });
  }

  Future<void> markOnboardingDone() async {
    state = state.copyWith(onboardingDone: true);
    await _write({SettingKeys.onboardingDone: '1'});
  }

  Future<void> setLastUsedUnit(String unit) async {
    state = state.copyWith(lastUsedUnit: unit);
    await _write({SettingKeys.lastUsedUnit: unit});
  }

  /// 铃铛点击：置为当日已读，红点熄灭（§5.2）。
  Future<void> markBellRead() async {
    final today = DateTime.now();
    final value = '${today.year}-${today.month}-${today.day}';
    state = state.copyWith(bellReadDate: DateTime(today.year, today.month, today.day));
    await _write({SettingKeys.bellReadDate: value});
  }

  bool get bellHasUnread {
    final now = DateTime.now();
    final read = state.bellReadDate;
    return read == null ||
        !(read.year == now.year && read.month == now.month && read.day == now.day);
  }
}

/// main() 启动时注入的初始设置快照。
final settingsSeedProvider = Provider<SettingsState>((ref) {
  throw UnimplementedError('main() 启动时以 override 注入');
});

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

/// 启动期 KV → 设置快照（main() 使用）。
SettingsState settingsFromMap(Map<String, String> m) {
  ThemeMode modeOf(String? v) =>
      v == 'light' ? ThemeMode.light : v == 'dark' ? ThemeMode.dark : ThemeMode.system;
  int? intOf(String? v) => int.tryParse(v ?? '');
  return SettingsState(
    themeMode: modeOf(m[SettingKeys.themeMode]),
    nickname: m[SettingKeys.nickname] ?? SettingDefaults.nickname,
    expiryWarningDays:
        intOf(m[SettingKeys.expiryWarningDays]) ?? SettingDefaults.expiryWarningDays,
    lowRemainingPercent:
        intOf(m[SettingKeys.lowRemainingPercent]) ?? SettingDefaults.lowRemainingPercent,
    dailySummaryEnabled: m[SettingKeys.dailySummaryEnabled] != '0',
    summaryHour: intOf(m[SettingKeys.summaryHour]) ?? SettingDefaults.summaryHour,
    summaryMinute: intOf(m[SettingKeys.summaryMinute]) ?? SettingDefaults.summaryMinute,
    autoBackupEnabled: m[SettingKeys.autoBackupEnabled] != '0',
    backupKeepCount: intOf(m[SettingKeys.backupKeepCount]) ?? SettingDefaults.backupKeepCount,
    lastBackupAt: m[SettingKeys.lastBackupAt] != null
        ? DateTime.tryParse(m[SettingKeys.lastBackupAt]!)
    : null,
    lastBackupSize: intOf(m[SettingKeys.lastBackupSize]),
    lastBackupOk: m[SettingKeys.lastBackupOk] != '0',
    lastBackupError: m[SettingKeys.lastBackupError] ?? '',
    onboardingDone: m[SettingKeys.onboardingDone] == '1',
    lastUsedUnit: m[SettingKeys.lastUsedUnit],
    bellReadDate: m[SettingKeys.bellReadDate] != null
        ? _parseLocalDay(m[SettingKeys.bellReadDate]!)
        : null,
  );
}

DateTime? _parseLocalDay(String v) {
  final p = v.split('-').map((e) => int.tryParse(e)).toList();
  if (p.length != 3 || p.any((e) => e == null)) return null;
  return DateTime(p[0]!, p[1]!, p[2]!);
}
