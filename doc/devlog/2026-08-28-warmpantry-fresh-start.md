# 2026-08-28 暖仓 WarmPantry 全新开发（T006）

## 背景与决策

- 用户确认「推翻重来」：旧版扁平 Item 模型（sqflite，无批次/开封/流水）到 Item/Batch + 流水结构的迁移造价高且必然失真，App 个人自用无外部用户，故不迁移旧数据、不兼容旧 JSON 备份。
- requirement.md 已按十七次修订落入该决策（§2.3 / §6.1 / §7.1 / §8）。
- 旧实现（`lib/app_store.dart`、`lib/pages/`、`lib/repository/`、旧 `test/`）整体移除，不设新旧双轨。

## 实现范围（requirement.md 对齐）

- **数据层**：drift schema v1（categories / storage_locations / items / batches / inventory_logs / repurchase_items / settings KV），独立数据库文件 `warmpantry.sqlite`，不读取旧库文件。
- **业务层**：InventoryService 承载 §4 全部业务规则——有效到期日、效期四级状态色、FIFO 跨批次消耗落点、开封/取消开封/改开封信息留痕、余量校正、移位、用完归档（告别语=入库→归档时长）、两段式软删（5 秒撤销 + 冷启动清扫）、回购清单、统计口径（今日消耗/近 7 天柱状/连续记录/节流成就/平均使用周期）。
- **服务层**：
  - 备份：ZIP（backup.json schema v1 + images/）导出、校验通过才标记成功、失败红色 pill、自动备份（每日首次启动 + 变更后 30 秒防抖）、恢复前自动预导出「后悔药」、恢复后补齐预置、滚动淘汰仅作用于私有自动备份目录。
  - 通知：摘要 = App 内预计算 + 系统定时投递；每次启动/数据变更/改设置后重挂未来 7 天（周日用周报口径）；POST_NOTIFICATIONS 按需申请；精确闹钟降级非精确。
  - 图片：image_picker 采集（maxWidth 1280 + quality 80 满足 §4.10 压缩）、更换先覆盖后改引用、备份成功后孤儿扫描。
  - 种子：首启引导写 8 预置分类 + 8 预置位置（可跳过位置）。
- **界面**：14 屏全部落地（home / library / consume / mine / editor / item_detail / categories / locations / expiring / archive / backup / about / onboarding + 悬浮 TabBar+FAB 壳），样式走 `core/theme`（design-system 浅深双主题 + AppColors ThemeExtension）。
- **Android**：应用名「暖仓」；权限收敛为通知/闹钟/相机/媒体（移除 INTERNET，debug 清单单独保留热重载所需）；补 flutter_local_notifications 计划通知与 BOOT_COMPLETED 接收器。

## 验证

- `dart analyze`：No issues found（0 error / 0 warning / 0 info）。
- `flutter test`：35 项全部通过，含真实链路 smoke——drift 建库→种子→入库→FIFO 消耗→归档→ZIP 导出→清库→恢复→数据一致 + 预置补齐 + 备份滚动淘汰。
- `flutter build apk --debug`：见提交说明（当日执行结果）。

## 有意偏离 / 待办（P1-P2 尾量）

1. **手动导出位置**：requirement §7.1 固定写 Download/WarmPantry；Android 10+ 公共 Download 需 MediaStore/SAF，实现为「私有导出目录 + 系统分享面板」（分享即存），与原型的旧版假设不同，已在代码注释与本文登记。
2. **编辑物品**：编辑不直接改数量（引导走校正，避免账实不符），效期/位置/规格/照片可改。
3. **P2 项**：年度报告（§5.15）、先吃先用清单（入口占位在临期页按钮）、徽章（我的页已挂，触发条件为基础版）、效期强提醒区域角标，均为最小实现或占位，待后续迭代。
4. **数字衬线字体**：Fraunces ttf 未打包，numeric 家族回退系统 serif，账本感成立；后续可下载字体子集打包。
