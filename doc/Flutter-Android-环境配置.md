# Flutter Android 环境配置指南（Windows）

> 适用场景：在 Windows 上配置 Flutter Android 开发环境，并通过 USB 连接 Android 真机调试。
> 目标读者：第一次手动配置 Flutter / Android SDK 的开发者。
> 示例目录：本文示例统一放在 `D:\Soft` 下，可按团队习惯替换为其他无中文、无空格、无需管理员权限的目录。

## 目录规划

建议将 SDK 和缓存放到 D 盘，避免占用系统盘，也避免路径权限问题：

| 用途 | 建议路径 |
| --- | --- |
| Flutter SDK | `D:\Soft\flutter` |
| Pub 缓存 | `D:\Soft\flutter_pub_cache` |
| Android SDK | `D:\Soft\Android\Sdk` |
| Android SDK 临时下载目录 | `D:\Soft\Android\tmp` |

创建目录：

```powershell
New-Item -ItemType Directory -Force -Path `
  D:\Soft, `
  D:\Soft\Android\Sdk, `
  D:\Soft\Android\tmp, `
  D:\Soft\flutter_pub_cache
```

## 下载 Flutter SDK

### 下载地址

- Flutter 中国站手动安装说明：<https://docs.flutter.cn/install/manual>
- Flutter SDK 发布页：<https://docs.flutter.cn/release/archive>

下载 Windows stable 版本的 ZIP 包，例如：

```text
flutter_windows_3.41.9-stable.zip
```

假设下载到：

```text
D:\Soft\flutter_windows_3.41.9-stable.zip
```

### 解压 Flutter SDK

```powershell
Expand-Archive `
  -LiteralPath D:\Soft\flutter_windows_3.41.9-stable.zip `
  -DestinationPath D:\Soft `
  -Force
```

解压后应存在：

```text
D:\Soft\flutter\bin\flutter.bat
```

检查：

```powershell
Test-Path D:\Soft\flutter\bin\flutter.bat
```

## 配置 Flutter 环境变量

配置用户级环境变量，不需要管理员权限：

```powershell
$flutterBin = 'D:\Soft\flutter\bin'
$pubCache = 'D:\Soft\flutter_pub_cache'

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @()
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $parts = $userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
if ($parts -notcontains $flutterBin) {
    $parts += $flutterBin
}

[Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
[Environment]::SetEnvironmentVariable('PUB_CACHE', $pubCache, 'User')
```

国内网络建议配置 Flutter / Pub 镜像：

```powershell
[Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

让当前 PowerShell 立即生效：

```powershell
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
$env:PUB_CACHE = [Environment]::GetEnvironmentVariable('PUB_CACHE', 'User')
$env:PUB_HOSTED_URL = [Environment]::GetEnvironmentVariable('PUB_HOSTED_URL', 'User')
$env:FLUTTER_STORAGE_BASE_URL = [Environment]::GetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'User')
```

验证：

```powershell
flutter --version
dart --version
```

## 准备 Java

Android SDK 工具和 Gradle 构建需要 JDK。

可选方案：

1. 使用 Android Studio 自带 JBR / JDK。
2. 使用 Visual Studio 附带的 OpenJDK。
3. 单独安装 JDK 17 或更高版本。

如果机器已有 Java，先查找：

```powershell
where.exe java
```

本文示例使用 Visual Studio 附带的 OpenJDK：

```text
D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8
```

配置用户级 `JAVA_HOME`：

```powershell
$javaHome = 'D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8'

[Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHome, 'User')

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @()
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $parts = $userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
$javaBin = Join-Path $javaHome 'bin'
if ($parts -notcontains $javaBin) {
    $parts += $javaBin
}
[Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
```

当前 PowerShell 立即生效：

```powershell
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
java -version
```

## 下载 Android Command-line Tools

Android Studio 不是必须项。只做命令行真机调试时，可以只安装 Android SDK Command-line Tools。

### 下载地址

- Android Studio / Command-line Tools 官方下载页：<https://developer.android.com/studio>
- Windows Command-line Tools 直链示例：

```text
https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip
```

下载到：

```text
D:\Soft\Android\tmp\commandlinetools-win.zip
```

PowerShell 下载命令：

```powershell
$url = 'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip'
$zip = 'D:\Soft\Android\tmp\commandlinetools-win.zip'

curl.exe -L --fail --retry 5 --retry-delay 5 --connect-timeout 30 --output $zip $url
```

校验 ZIP 能否读取：

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead('D:\Soft\Android\tmp\commandlinetools-win.zip')
$archive.Entries.Count
$archive.Dispose()
```

如果报 `End of Central Directory record could not be found`，说明 ZIP 下载不完整，删除后重新下载。

### 解压到 Android SDK 规范目录

Android Command-line Tools 必须放在：

```text
<Android SDK>\cmdline-tools\latest
```

执行：

```powershell
$sdk = 'D:\Soft\Android\Sdk'
$zip = 'D:\Soft\Android\tmp\commandlinetools-win.zip'
$extract = 'D:\Soft\Android\tmp\cmdline-extract'
$latest = Join-Path $sdk 'cmdline-tools\latest'

Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $latest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $extract, (Split-Path $latest -Parent) | Out-Null

Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
Move-Item -LiteralPath (Join-Path $extract 'cmdline-tools') -Destination $latest
```

检查：

```powershell
Test-Path D:\Soft\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat
```

## 配置 Android SDK 环境变量

```powershell
$sdk = 'D:\Soft\Android\Sdk'

[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdk, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdk, 'User')

$addPaths = @(
  (Join-Path $sdk 'platform-tools'),
  (Join-Path $sdk 'cmdline-tools\latest\bin')
)

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @()
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $parts = $userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
foreach ($path in $addPaths) {
    if ($parts -notcontains $path) {
        $parts += $path
    }
}
[Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
```

当前 PowerShell 立即生效：

```powershell
$env:ANDROID_SDK_ROOT = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User')
$env:ANDROID_HOME = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
```

验证：

```powershell
sdkmanager --version
```

## 安装 Android SDK 组件

先接受 SDK licenses：

```powershell
1..30 | ForEach-Object { 'y' } | sdkmanager --licenses
```

安装真机调试和 Flutter Android 构建所需组件：

```powershell
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "build-tools;28.0.3"
```

兼容旧项目时，可按需安装旧版平台或构建工具：

```powershell
sdkmanager "platforms;android-35" "build-tools;35.0.0"
```

说明：

- `platform-tools` 提供 `adb`，真机调试必须安装。
- `platforms;android-36` 提供 Android 36 平台 SDK。
- `build-tools;36.0.0` 满足新版本 Flutter / Android 构建需求。
- `build-tools;28.0.3` 是 Flutter Doctor 可能要求的兼容项。

配置 Flutter 使用该 Android SDK：

```powershell
flutter config --android-sdk D:\Soft\Android\Sdk
```

## 验证开发环境

执行：

```powershell
flutter doctor -v
adb version
adb devices -l
flutter devices
```

理想结果：

- `flutter doctor -v` 中 Android toolchain 为通过状态。
- `adb version` 能输出版本号。
- 手机连接并授权后，`adb devices -l` 能看到设备。
- `flutter devices` 能看到 Android 设备。

Chrome 缺失只影响 Web 调试，不影响 Android 真机调试。

## 配置 Flutter 项目

进入 Flutter 项目根目录：

```powershell
cd D:\GitHub\MyItems
```

安装项目依赖：

```powershell
flutter pub get
```

静态检查：

```powershell
flutter analyze
```

运行测试：

```powershell
flutter test
```

构建 Debug APK：

```powershell
flutter build apk --debug
```

如果首次构建长时间卡住，用详细日志定位：

```powershell
flutter build apk --debug -v
```

## Android 真机调试

手机侧操作：

1. 打开「设置」。
2. 连续点击系统版本号，开启开发者选项。
3. 进入开发者选项。
4. 开启 USB 调试。
5. 使用支持数据传输的 USB 线连接电脑。
6. 手机上弹出授权提示时，点击允许。

电脑侧检查：

```powershell
adb devices -l
```

常见状态：

| 状态 | 含义 | 处理 |
| --- | --- | --- |
| `device` | 已授权，可调试 | 直接运行 `flutter run` |
| `unauthorized` | 手机未授权 | 查看手机弹窗并允许；必要时重新插线 |
| 空列表 | 未识别设备 | 检查 USB 线、USB 模式、驱动和开发者选项 |

重启 ADB：

```powershell
adb kill-server
adb start-server
adb devices -l
```

运行到真机：

```powershell
flutter run
```

指定设备运行：

```powershell
flutter devices
flutter run -d <device-id>
```

### Flutter 项目真机调试流程

Android 环境配置完成后，每次调试项目通常按下面顺序执行。

进入 Flutter 项目根目录：

```powershell
cd D:\GitHub\MyItems
```

恢复依赖：

```powershell
flutter pub get
```

确认 Flutter 能识别手机：

```powershell
flutter devices
```

启动 Debug 调试：

```powershell
flutter run
```

如果同时连接了多个设备，先查看设备 ID，再指定设备运行：

```powershell
flutter devices
flutter run -d <device-id>
```

`flutter run` 运行后，终端中常用快捷键如下：

| 快捷键 | 作用 |
| --- | --- |
| `r` | Hot reload，适合修改 UI、样式和大多数 Dart 代码 |
| `R` | Hot restart，适合修改初始化逻辑、全局状态或 reload 不生效的场景 |
| `h` | 查看调试快捷键帮助 |
| `q` | 退出调试会话 |

查看 Flutter 日志：

```powershell
flutter logs
```

查看 Android 设备日志：

```powershell
adb logcat
```

构建并安装 Debug APK：

```powershell
flutter build apk --debug
adb install -r .\build\app\outputs\flutter-apk\app-debug.apk
```

说明：

- Android Studio 不是命令行真机调试的必需项。
- 使用 VS Code、Android Studio 或纯 PowerShell 调试都可以，关键是 `flutter doctor -v` 中 Android toolchain 通过，且 `flutter devices` 能看到真机。
- 修改原生 Android 配置后，建议先退出 `flutter run`，再重新执行 `flutter run`。
- 如果只改 Dart 页面代码，优先使用 hot reload，不需要每次重新安装 APK。

## 常见问题

### `flutter doctor` 找不到 Android SDK

确认环境变量：

```powershell
echo $env:ANDROID_SDK_ROOT
echo $env:ANDROID_HOME
```

重新配置：

```powershell
flutter config --android-sdk D:\Soft\Android\Sdk
```

### `sdkmanager` 无法运行

检查路径：

```powershell
where.exe sdkmanager
where.exe java
```

确认已配置：

```powershell
echo $env:JAVA_HOME
echo $env:ANDROID_SDK_ROOT
```

### `adb devices` 看不到手机

按顺序检查：

1. USB 线是否支持数据传输。
2. 手机是否开启 USB 调试。
3. 手机是否弹出并确认调试授权。
4. 手机 USB 模式是否为文件传输或调试可用模式。
5. Windows 设备管理器是否缺少手机厂商 USB 驱动。

### Gradle / Maven 下载慢

首次 `flutter build apk` 需要下载 Gradle 和 Maven 依赖。网络不稳定时可能长时间卡住。

先用详细日志确认卡点：

```powershell
flutter build apk --debug -v
```

如果确认是 Maven 依赖下载慢，再考虑配置 Gradle 镜像。镜像会改变依赖解析来源，建议团队确认后统一配置。

## 本机示例结果

以下是一次实际配置后的示例，仅用于对照：

- Flutter SDK：`D:\Soft\flutter`
- Android SDK：`D:\Soft\Android\Sdk`
- Java：`D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8`
- `flutter doctor -v`：Android toolchain 通过，Android SDK version `36.0.0`
- `flutter analyze`：通过
- `flutter test`：通过
- `adb devices -l`：未连接真机时为空列表
