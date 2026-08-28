# Flutter Android 迁移实现计划

> ⚠️ **历史归档（2026-08-29）**：本计划基于旧 sqflite/CSV 技术栈，已由 2026-08-28 的「暖仓 WarmPantry 全新开发」（TASK T006，见 `doc/devlog/2026-08-28-warmpantry-fresh-start.md`）整体取代：技术栈切换为 Riverpod + GoRouter + drift，不迁移旧数据。保留本文仅作过程记录。

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 或等价分步执行方式。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 `flutter` 分支新增 Flutter Android 版本，覆盖当前「我的物品」App 的核心 Android 使用链路，并保留原 MAUI 工程作为迁移参考。

**架构：** Flutter 版本采用 `View → ChangeNotifier Store → Repository → SQLite` 的轻量分层。UI 层负责展示与输入，Store 层负责页面状态和业务编排，Repository 层封装本地持久化与查询，模型层承载数据和状态计算。

**技术栈：** Flutter、Dart、Material 3、`sqflite`、`path_provider`、`csv`、`flutter_test`。

---

## 文件结构

- 创建 `pubspec.yaml`：Flutter 依赖、资源与测试配置。
- 创建 `analysis_options.yaml`：Dart 静态检查规则。
- 创建 `android/`：Flutter Android 壳工程和 `AndroidManifest.xml`。
- 创建 `lib/main.dart`：应用入口、主题、导航骨架。
- 创建 `lib/models.dart`：分类、物品、DTO、过期状态与格式化逻辑。
- 创建 `lib/repository.dart`：SQLite 初始化、迁移、CRUD、查询、CSV 导入导出。
- 创建 `lib/app_store.dart`：页面状态、添加编辑、搜索筛选、分类管理、删除逻辑。
- 创建 `lib/pages.dart`：主页、物品库、详情、添加编辑、分类、关于页面。
- 创建 `test/status_helper_test.dart`：过期状态、日均成本、搜索过滤行为测试。
- 修改 `README.md`：补充 Flutter Android 运行方式与当前环境限制。
- 修改 `TASK.md`：新增 Flutter 迁移任务记录。
- 新增 `doc/devlog/`：记录迁移实现、验证情况和遗留项。

## 任务 1：任务与计划记录

**文件：**
- 创建：`doc/design/flutter-android-migration-plan.md`
- 修改：`TASK.md`

- [x] **步骤 1：写入迁移计划**

保存当前计划，明确保留 MAUI 工程、不删除旧源码、Flutter 工程新增在仓库根目录。

- [ ] **步骤 2：更新任务状态**

在 `TASK.md` 新增 `T052`，状态为 `DOING`，阶段为 `阶段 3`，负责人为 `Codex`。

## 任务 2：Flutter 工程骨架

**文件：**
- 创建：`pubspec.yaml`
- 创建：`analysis_options.yaml`
- 创建：`android/settings.gradle`
- 创建：`android/build.gradle`
- 创建：`android/app/build.gradle`
- 创建：`android/app/src/main/AndroidManifest.xml`
- 创建：`android/app/src/main/kotlin/com/azrng/myitems/MainActivity.kt`

- [ ] **步骤 1：创建 Flutter 项目配置**

定义项目名、版本、Flutter SDK 约束和依赖：`sqflite`、`path`、`path_provider`、`csv`。

- [ ] **步骤 2：创建 Android 壳工程**

使用 Flutter Gradle 插件结构，应用 ID 为 `com.azrng.myitems`，最低 Android SDK 为 26。

## 任务 3：核心模型和业务规则

**文件：**
- 创建：`lib/models.dart`
- 测试：`test/status_helper_test.dart`

- [ ] **步骤 1：编写失败测试**

覆盖已过期、临期、安全、无保质期、日均成本和搜索匹配。

- [ ] **步骤 2：实现模型和状态计算**

实现 `Item`、`Category`、`ItemDisplay`、`ExpiryGroup`、`ExpiryStatus` 和格式化方法。

## 任务 4：SQLite 数据层

**文件：**
- 创建：`lib/repository.dart`

- [ ] **步骤 1：实现数据库初始化**

创建 `categories`、`items`、`version_log` 表，插入预置分类。

- [ ] **步骤 2：实现查询和写入**

实现分类 CRUD、物品 CRUD、软删除、分页查询、过期分组、统计查询。

- [ ] **步骤 3：实现 CSV 导入导出**

导出分类和物品表；导入时按名称匹配分类，按 ID 或名称更新物品。

## 任务 5：应用状态层

**文件：**
- 创建：`lib/app_store.dart`

- [ ] **步骤 1：实现初始化和刷新**

加载分类、主页分组、物品库列表和统计。

- [ ] **步骤 2：实现表单保存**

校验名称和分类，保存新物品或编辑物品，保存后刷新数据。

- [ ] **步骤 3：实现分类管理**

支持新增分类、删除自定义分类、阻止删除预置或有关联物品的分类。

## 任务 6：Flutter 页面实现

**文件：**
- 创建：`lib/main.dart`
- 创建：`lib/pages.dart`

- [ ] **步骤 1：实现主题和导航**

Material 3 主题对齐现有主色，底部导航覆盖主页、物品库、分类，侧边抽屉覆盖添加和关于。

- [ ] **步骤 2：实现主要页面**

实现主页、物品库、详情、添加编辑、分类、关于页面，覆盖 loading、empty、error 状态。

## 任务 7：文档、验证与提交

**文件：**
- 修改：`README.md`
- 创建：`doc/devlog/YYYY-MM-DD-HH-mm-ss-Flutter安卓迁移.md`
- 修改：`TASK.md`

- [ ] **步骤 1：更新文档**

说明 Flutter SDK、Android 构建链依赖和运行命令。

- [ ] **步骤 2：执行可用验证**

当前环境无 `flutter`、`dart`、`java`、`gradle`、Android SDK，只能执行文件结构、Git 状态和关键文本回读验证。

- [ ] **步骤 3：提交**

使用中文 Conventional Commit，记录未执行 Flutter 构建的原因和风险。

