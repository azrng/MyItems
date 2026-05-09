# MyItems（我的物品）

个人物品管理应用，Flutter Android 版本。

`main` 分支保留原 .NET MAUI 源码作为历史参考。

## 环境要求

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
├── models.dart        # 物品、分类、消耗记录、展示 DTO 和过期状态计算
├── repository.dart    # SQLite 初始化、CRUD、统计、完整备份和 CSV 兼容导入导出
├── app_store.dart     # 页面状态、保存、筛选、分类与存储位置管理
└── pages.dart         # 主页、物品库、详情、添加编辑、分类、存储管理、归档、关于

android/               # Flutter Android 壳工程
test/                  # Flutter 单元测试
```

### 首次构建

安装 Flutter 和 Android 构建链后，在仓库根目录执行：

```powershell
flutter pub get
flutter test
flutter build apk --debug
```

### Release 构建

Release APK 需要签名才能安装。项目已配置签名，需先创建 `android/key.properties`：

```properties
storePassword=<密码>
keyPassword=<密码>
keyAlias=upload
storeFile=<keystore 文件路径>
```

然后执行：

```powershell
flutter build apk
```

产物路径：`build/app/outputs/flutter-apk/app-release.apk`

> CI 构建通过 GitHub Actions 自动签名，密钥存储在仓库 Secrets 中。

### 本项目快速运行命令

已连接并授权 Android 手机后，在 PowerShell 中执行：

```powershell
cd D:\GitHub\MyItems

$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:ANDROID_SDK_ROOT = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User')
$env:ANDROID_HOME = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

flutter pub get
flutter devices
flutter run -d 882QAETJEYG3S --debug
```

其中 `882QAETJEYG3S` 是本机当前识别到的魅族 16th 设备 ID。换手机后，先执行：

```powershell
flutter devices
```

再把启动命令里的设备 ID 替换成新的设备 ID：

```powershell
flutter run -d <device-id> --debug
```

如果只想构建 Debug APK，不进入驻留调试会话，执行：

```powershell
flutter build apk --debug
```

构建产物路径：

```text
build\app\outputs\flutter-apk\app-debug.apk
```


