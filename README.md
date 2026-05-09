# MyItems（我的物品）

个人物品管理应用，当前 `main` 分支基于 .NET MAUI，支持 Android 和 Windows 平台。

`flutter` 分支正在迁移为 Flutter Android 版本，保留原 MAUI 源码作为功能对照。

## Flutter Android 版本

### 环境要求

- Flutter SDK
- Dart SDK（随 Flutter SDK 提供）
- Java 17
- Android SDK
- Android SDK Command-line Tools 或 Android Studio

当前已验证 Flutter、Dart、Java、Android SDK、ADB 和魅族 16th 真机识别。详细安装与排错说明见 [Flutter Android 环境配置指南](doc/Flutter-Android-环境配置.md)。

### 目录说明

```text
lib/
├── main.dart          # 应用入口、主题和全局 Store 注入
├── models.dart        # 物品、分类、展示 DTO 和过期状态计算
├── repository.dart    # SQLite 初始化、CRUD、统计、CSV 导入导出
├── app_store.dart     # 页面状态、保存、筛选、分类管理
└── pages.dart         # 主页、物品库、详情、添加编辑、分类、关于

android/               # Flutter Android 壳工程
test/                  # Flutter 单元测试
```

### 首次构建

安装 Flutter 和 Android 构建链后，在仓库根目录执行：

```bash
flutter pub get
flutter test
flutter build apk --debug
```

连接 Android 真机调试：

```powershell
flutter devices
flutter run -d <device-id> --debug
```

本机魅族 16th 的设备 ID 示例：

```powershell
flutter run -d 882QAETJEYG3S --debug
```

## 数据库迁移

项目使用嵌入式 SQL 文件管理数据库版本迁移，所有 schema 变更通过 SQL 文件驱动。

### 迁移文件命名规则

```
src/MyItems/Migrations/V{版本号}__{描述}.sql
```

- 版本号：递增整数，从 1 开始
- 描述：用下划线连接的简短说明
- 示例：`V1__init.sql`、`V2__add_tag_column.sql`

### 新增迁移

需要修改数据库 schema 时，在 `src/MyItems/Migrations/` 目录下新建 SQL 文件：

```sql
-- V2: 新增标签列
ALTER TABLE Items ADD COLUMN Tag TEXT;
```

无需其他代码改动，应用启动时会自动检测并执行新版本迁移。

### 执行机制

1. 应用启动时创建 `VersionLog` 表，读取当前数据库版本
2. 扫描嵌入式资源中的 SQL 文件，筛选版本号大于当前版本的文件
3. 按版本号升序逐个执行：按 `;` 分割语句，过滤注释行，逐条执行
4. 每个文件执行完毕后在 `VersionLog` 表插入版本记录

### 注意事项

- SQL 文件通过 `csproj` 中的 `<EmbeddedResource Include="Migrations\*.sql" />` 编译为嵌入式资源
- 使用 `CREATE TABLE IF NOT EXISTS` 和 `INSERT OR IGNORE` 确保幂等性，兼容已有数据库
- 迁移在单个文件内按 `;` 分割执行，不支持事务回滚，请确保 SQL 语句正确
