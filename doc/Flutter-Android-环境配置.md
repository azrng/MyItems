# Flutter Android 环境配置

> 更新日期：2026-05-09  
> 适用分支：`flutter`  
> 目标：在 Windows 上使用 Flutter 调试 Android 真机。

## 安装位置

| 组件 | 路径 |
| --- | --- |
| Flutter SDK | `D:\Soft\flutter` |
| Pub 缓存 | `D:\Soft\flutter_pub_cache` |
| Android SDK | `D:\Soft\Android\Sdk` |
| Android Command-line Tools | `D:\Soft\Android\Sdk\cmdline-tools\latest` |
| Java | `D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8` |

## 用户级环境变量

已写入用户级环境变量：

```powershell
PATH += D:\Soft\flutter\bin
PATH += D:\Soft\Android\Sdk\platform-tools
PATH += D:\Soft\Android\Sdk\cmdline-tools\latest\bin
PATH += D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8\bin

PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
PUB_CACHE=D:\Soft\flutter_pub_cache

ANDROID_SDK_ROOT=D:\Soft\Android\Sdk
ANDROID_HOME=D:\Soft\Android\Sdk
JAVA_HOME=D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8
```

新打开的 PowerShell / IDE 会自动读取用户级环境变量；已打开的终端或 IDE 需要重启。

## 已安装 Android SDK 组件

通过 `sdkmanager` 安装：

```powershell
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
sdkmanager "platforms;android-36" "build-tools;36.0.0" "build-tools;28.0.3"
```

已执行并接受 Android SDK licenses：

```powershell
sdkmanager --licenses
```

Flutter 已配置 Android SDK 路径：

```powershell
flutter config --android-sdk D:\Soft\Android\Sdk
```

## 验证命令

在仓库根目录执行：

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
adb devices -l
flutter devices
```

当前验证结果：

- `flutter doctor -v`：Flutter、Windows、Android toolchain、Visual Studio、Connected device 均可识别。
- Android toolchain：已通过，Android SDK version `36.0.0`。
- Chrome：未安装或未配置，不影响 Android 真机调试。
- Network resources：访问 `storage.googleapis.com`、`maven.google.com` 偶发超时或 TLS 握手错误，当前项目依赖可通过 Flutter 中国镜像下载。
- `flutter pub get`：通过。
- `flutter analyze`：通过，无问题。
- `flutter test`：通过，4 个测试全部通过。
- `adb devices -l`：当前未发现 Android 真机。

## 真机调试步骤

1. 手机开启开发者选项。
2. 开启 USB 调试。
3. 使用 USB 数据线连接电脑。
4. 手机上确认「允许 USB 调试」授权。
5. 在仓库根目录执行：

```powershell
adb devices -l
flutter devices
flutter run
```

如果 `adb devices -l` 显示 `unauthorized`，在手机上重新确认授权；必要时执行：

```powershell
adb kill-server
adb start-server
adb devices -l
```

如果完全不显示设备，优先检查：

- USB 线是否支持数据传输。
- 手机 USB 模式是否为文件传输或调试可用模式。
- Windows 设备管理器是否缺少手机厂商 USB 驱动。

## 当前构建情况

已尝试：

```powershell
flutter build apk --debug
```

结果：命令运行超过 15 分钟后超时，没有生成 APK 产物。超时后已手动终止遗留的 Dart / Java 构建进程。

该问题更可能与首次 Gradle 依赖下载、网络访问 `maven.google.com` 不稳定有关。后续建议：

1. 保持网络稳定后重新运行：

```powershell
flutter build apk --debug
```

2. 若仍卡住，使用详细日志定位：

```powershell
flutter build apk --debug -v
```

3. 若确认是 Gradle / Maven 下载慢，再考虑配置 Gradle 镜像。配置镜像会改变构建解析来源，建议单独确认后再改。

## 不依赖 Android Studio 的说明

当前方案没有安装 Android Studio，只安装 Android SDK Command-line Tools 和必要 SDK 组件。

这种方式足够进行命令行真机调试：

```powershell
flutter run
```

如果需要图形化 SDK Manager、模拟器管理器、Logcat、布局检查等 IDE 能力，再安装 Android Studio。

