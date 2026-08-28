# 暖仓 WarmPantry

家庭物品管理 App「暖仓 WarmPantry」——把日子过得清清楚楚 🧺。跟踪物品保质期与余量消耗，管理分类与存放位置。

- 技术栈：Flutter + Material 3 + Riverpod + GoRouter + drift（requirement.md §6.1）
- 设计基准：`doc/prototype/`（奶油暖盘视觉）+ `design-system.yaml`（token 唯一事实来源）
- 数据完全本地存储，无网络传输；备份为 ZIP（backup.json + images/）
- 2026-08-28 全新开发（不兼容旧版数据与旧 JSON 备份，见 requirement.md 十七次修订）

## 环境要求

- Flutter SDK（stable 3.x）
- Dart SDK（随 Flutter SDK 提供）
- Java 17
- Android SDK（最低 Android 8.0 / API 26）

详细安装与排错说明见 [Flutter Android 环境配置指南](doc/Flutter-Android-环境配置.md)。

### 目录说明

```text
lib/
├── main.dart               # 应用入口：目录装配 + 设置快照注入
├── app.dart                # MaterialApp.router + 浅色/深色主题
├── core/                   # 主题（design-system token 落地）/ 常量 / 效期规则 / 工具
├── data/
│   ├── database/           # drift 表定义与数据库（schema v1）
│   ├── repositories/       # 数据访问边界（抽象 + drift 实现）
│   └── services/           # 库存业务 / 备份 / 通知 / 种子 / 图片
├── providers/              # Riverpod：DI、设置、数据流、视图组合、命令编排
├── router/                 # GoRouter：四 Tab + 子页
├── widgets/                # 共享组件（悬浮 TabBar / Tag / Meter / 弹层 / 统计卡）
└── features/               # 每目录对应原型一个屏幕（home/library/consume/mine/…）

android/                    # Flutter Android 壳工程
doc/                        # requirement.md（唯一需求基准）+ 原型
test/                       # 单元 + 真实链路（备份往返）测试
```

### 首次构建

安装 Flutter 和 Android 构建链后，在仓库根目录执行：

```powershell
flutter pub get
flutter test
flutter build apk --debug
```

### 本地启动（当前环境实测状态）

| 途径 | 状态 | 说明 |
|------|------|------|
| Android 真机 | ✅ 推荐 | USB 连接并授权调试后 `flutter run`；或直接安装已构建的 APK |
| Android 模拟器 | ❌ 暂不可用 | 本机未安装任何 AVD 系统镜像，需先在 Android Studio 下载 |
| Windows 桌面 | ⚠️ 需开关 | 代码可跑，但插件构建要求系统开启「开发者模式」（符号链接权限）：`start ms-settings:developers` |

真机运行：

```powershell
flutter devices          # 确认设备已识别
flutter run              # 默认选中唯一的手机设备
```

只装 APK 不驻留调试：

```powershell
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

首启会进入引导页：写入 8 个预置分类与 8 个预置位置（可跳过位置）。

### 版本固定说明

`sqlite3` 经 dependency_overrides 固定 2.4.6、drift/drift_dev 固定 2.20.3：sqlite3 ≥2.5 的原生构建钩子需联网访问 GitHub 下载预编译产物，代理/离线环境会构建失败；Android 原生库由 `sqlite3_flutter_libs` 提供，不受影响。详见 `doc/requirement.md` §6.3。

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
$version = (Get-Content .\VERSION -Raw).Trim()
flutter build apk --release --build-name $version --build-number 1 --dart-define "APP_VERSION=$version"
```

产物路径：`build/app/outputs/flutter-apk/app-release.apk`

> CI 构建通过 GitHub Actions 自动签名，密钥存储在仓库 Secrets 中。发布时会读取 `VERSION` 作为 Android `versionName` 和关于页展示版本，并使用 GitHub Actions 的 `GITHUB_RUN_NUMBER` 作为递增 `versionCode`，确保手机覆盖安装时能识别为新版本。

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


