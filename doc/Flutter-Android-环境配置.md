# Flutter Android 环境配置指南（Windows）

> 适用场景：在 Windows 电脑上安装 Flutter Android 开发环境，并用 Android 真机运行 Flutter 项目。
> 目标读者：第一次接触 Android 调试、不了解 Android SDK / ADB / Flutter Doctor 的同学。
> 示例目录：本文统一使用 `D:\Soft` 存放工具，使用 `D:\Code\your_flutter_app` 表示你的 Flutter 项目目录。

## 先读这个

本文的目标不是让你理解所有 Android 原理，而是让你能完成 3 件事：

1. 在 Windows 上安装 Flutter。
2. 安装 Android SDK 命令行工具，不依赖 Android Studio。
3. 用 USB 连接 Android 手机，执行 `flutter run` 把项目跑到真机上。

### 会安装哪些东西

| 工具 | 作用 | 是否必须 |
| --- | --- | --- |
| Flutter SDK | Flutter 命令行工具，提供 `flutter` 和 `dart` 命令 | 必须 |
| JDK | Java 开发工具，Android 构建时需要 | 必须 |
| Android Command-line Tools | Android SDK 命令行管理工具，提供 `sdkmanager` | 必须 |
| Android SDK Platform | Android 平台 API，编译 Android 应用时需要 | 必须 |
| Android SDK Build-Tools | Android 打包工具，生成 APK 时需要 | 必须 |
| Android Platform-Tools | 提供 `adb`，用于连接和调试手机 | 必须 |
| Android Studio | 图形化 IDE、模拟器、Logcat 等 | 非必须 |

### 本文约定

- 所有命令都在 Windows PowerShell 中执行。
- 不建议把 SDK 放到带中文、空格或权限复杂的目录，例如 `C:\Program Files`。
- 本文写的是用户级环境变量，不需要管理员权限。
- 如果公司或学校网络无法访问 Google 下载源，可以先使用 Flutter 中国镜像。

## 第 0 步：打开 PowerShell

后续命令都在 PowerShell 中运行。

打开方式：

1. 按 `Win` 键。
2. 输入 `PowerShell`。
3. 点击「Windows PowerShell」。
4. 不需要选择「以管理员身份运行」。

可以先执行下面命令确认 PowerShell 正常：

```powershell
$PSVersionTable.PSVersion
```

能看到版本号就可以继续。

## 第 1 步：规划目录

建议使用下面目录：

| 用途 | 示例路径 |
| --- | --- |
| Flutter SDK | `D:\Soft\flutter` |
| Pub 缓存 | `D:\Soft\flutter_pub_cache` |
| Android SDK | `D:\Soft\Android\Sdk` |
| Android SDK 临时下载目录 | `D:\Soft\Android\tmp` |
| 你的 Flutter 项目 | `D:\Code\your_flutter_app` |

执行下面命令创建目录：

```powershell
New-Item -ItemType Directory -Force -Path `
  D:\Soft, `
  D:\Soft\Android\Sdk, `
  D:\Soft\Android\tmp, `
  D:\Soft\flutter_pub_cache, `
  D:\Code
```

看到类似下面输出说明目录创建成功：

```text
Directory: D:\
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----           ...                       Soft
```

如果提示目录已存在，不是错误，可以继续。

## 第 2 步：下载 Flutter SDK

### 下载入口

优先从官方页面下载：

- Flutter 中国站手动安装说明：<https://docs.flutter.cn/install/manual>
- Flutter SDK 发布页：<https://docs.flutter.cn/release/archive>

在发布页选择：

1. 操作系统选择 Windows。
2. 渠道选择 stable。
3. 下载 ZIP 压缩包。

文件名通常类似：

```text
flutter_windows_3.41.9-stable.zip
```

本文假设下载到了：

```text
D:\Soft\flutter_windows_3.41.9-stable.zip
```

如果你的文件名不同，后面命令中的文件名要替换成你实际下载的文件名。

### 解压 Flutter SDK

执行：

```powershell
Expand-Archive `
  -LiteralPath D:\Soft\flutter_windows_3.41.9-stable.zip `
  -DestinationPath D:\Soft `
  -Force
```

解压完成后检查 Flutter 命令是否存在：

```powershell
Test-Path D:\Soft\flutter\bin\flutter.bat
```

期望输出：

```text
True
```

如果输出 `False`，通常是 ZIP 没有解压到 `D:\Soft`，或者解压后多了一层目录。打开 `D:\Soft` 看一下，最终必须存在：

```text
D:\Soft\flutter\bin\flutter.bat
```

## 第 3 步：配置 Flutter 环境变量

环境变量的作用是让你在任意目录输入 `flutter`，系统都能找到 `D:\Soft\flutter\bin\flutter.bat`。

执行：

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

国内网络建议继续执行：

```powershell
[Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', 'https://pub.flutter-io.cn', 'User')
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'User')
```

让当前 PowerShell 窗口立即读取新环境变量：

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

期望看到 Flutter 和 Dart 版本号，例如：

```text
Flutter 3.41.9 ...
Dart 3.11.5 ...
```

如果提示 `flutter` 不是内部或外部命令，关闭 PowerShell 重新打开，再执行 `flutter --version`。

## 第 4 步：准备 Java / JDK

Android 构建依赖 Java。你可以使用以下任一方式：

1. 已安装 Android Studio：使用 Android Studio 自带的 JDK。
2. 已安装 Visual Studio Android 工作负载：使用 Visual Studio 附带的 OpenJDK。
3. 单独安装 JDK 17 或更高版本。

先检查电脑是否已经有 Java：

```powershell
where.exe java
java -version
```

如果能看到 Java 路径和版本号，可以继续。如果没有 Java，需要先安装 JDK。

本文示例使用 Visual Studio 附带的 OpenJDK：

```text
D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8
```

如果你的 JDK 路径不同，把下面的 `$javaHome` 改成你的实际路径：

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

让当前 PowerShell 生效并验证：

```powershell
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'

echo $env:JAVA_HOME
java -version
```

期望结果：

- `echo $env:JAVA_HOME` 能显示你的 JDK 目录。
- `java -version` 能显示版本号。

## 第 5 步：下载 Android Command-line Tools

Android Studio 不是必须安装项。只做命令行真机调试时，安装 Android Command-line Tools 即可。

### 下载入口

官方页面：

- Android Studio / Command-line Tools 下载页：<https://developer.android.com/studio>

在页面中找到「Command line tools only」，下载 Windows 版本。

官方直链会随版本更新变化。2026-05-09 查询到的 Windows 最新文件名为：

```text
commandlinetools-win-14742923_latest.zip
```

下载到：

```text
D:\Soft\Android\tmp\commandlinetools-win.zip
```

可以浏览器下载，也可以用命令下载：

```powershell
$url = 'https://dl.google.com/android/repository/commandlinetools-win-14742923_latest.zip'
$zip = 'D:\Soft\Android\tmp\commandlinetools-win.zip'

curl.exe -L --fail --retry 5 --retry-delay 5 --connect-timeout 30 --output $zip $url
```

如果命令下载失败，直接用浏览器打开官方页面下载，然后把文件改名为：

```text
D:\Soft\Android\tmp\commandlinetools-win.zip
```

### 检查 ZIP 是否完整

执行：

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead('D:\Soft\Android\tmp\commandlinetools-win.zip')
$archive.Entries.Count
$archive.Dispose()
```

如果输出一个大于 `0` 的数字，说明 ZIP 能打开。

如果报错：

```text
End of Central Directory record could not be found
```

说明 ZIP 下载不完整，需要删除后重新下载。

## 第 6 步：解压 Android Command-line Tools

Android 命令行工具必须放到 Android SDK 的规范目录：

```text
D:\Soft\Android\Sdk\cmdline-tools\latest
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

检查 `sdkmanager` 是否存在：

```powershell
Test-Path D:\Soft\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat
```

期望输出：

```text
True
```

如果输出 `False`，说明目录层级不对。正确结构必须是：

```text
D:\Soft\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat
```

## 第 7 步：配置 Android SDK 环境变量

执行：

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

让当前 PowerShell 生效：

```powershell
$env:ANDROID_SDK_ROOT = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User')
$env:ANDROID_HOME = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
```

验证：

```powershell
echo $env:ANDROID_SDK_ROOT
sdkmanager --version
```

期望结果：

- `echo $env:ANDROID_SDK_ROOT` 输出 `D:\Soft\Android\Sdk`。
- `sdkmanager --version` 输出版本号。

## 第 8 步：安装 Android SDK 组件

先接受 Android SDK 许可：

```powershell
1..30 | ForEach-Object { 'y' } | sdkmanager --licenses
```

看到类似下面内容说明许可处理完成：

```text
All SDK package licenses accepted
```

安装真机调试和构建所需组件：

```powershell
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "build-tools;28.0.3"
```

兼容一些旧项目时，可以额外安装 Android 35：

```powershell
sdkmanager "platforms;android-35" "build-tools;35.0.0"
```

这些组件分别用于：

| 组件 | 作用 |
| --- | --- |
| `platform-tools` | 安装 `adb`，用于连接手机、安装 APK、查看设备 |
| `platforms;android-36` | Android 36 平台 API，编译项目时使用 |
| `build-tools;36.0.0` | Android 打包工具 |
| `build-tools;28.0.3` | Flutter Doctor 可能要求的兼容项 |

配置 Flutter 使用这个 Android SDK：

```powershell
flutter config --android-sdk D:\Soft\Android\Sdk
```

## 第 9 步：检查环境是否可用

如果你是刚配置完环境变量，建议先关闭当前 PowerShell，重新打开一个新的 PowerShell。

如果不想关闭窗口，也可以先执行下面命令，让当前窗口读取最新的用户级环境变量：

```powershell
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:ANDROID_SDK_ROOT = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User')
$env:ANDROID_HOME = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
$env:PUB_CACHE = [Environment]::GetEnvironmentVariable('PUB_CACHE', 'User')
$env:PUB_HOSTED_URL = [Environment]::GetEnvironmentVariable('PUB_HOSTED_URL', 'User')
$env:FLUTTER_STORAGE_BASE_URL = [Environment]::GetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'User')
```

这一步很重要。否则可能明明已经配置了环境变量，当前窗口里仍然提示：

```text
flutter 不是内部或外部命令
sdkmanager 不是内部或外部命令
JAVA_HOME is not set
```

执行：

```powershell
flutter doctor -v
adb version
flutter devices
```

你需要重点看 `flutter doctor -v` 里的 Android toolchain。

理想状态：

```text
[√] Android toolchain - develop for Android devices
```

如果 Chrome 缺失，不影响 Android 真机调试。Chrome 只影响 Flutter Web。

如果暂时没有连接手机，`flutter devices` 可能只显示 Windows 或空的 Android 设备列表，这是正常的。连接手机后再检查。

## 第 10 步：准备 Android 手机

不同手机菜单名字略有差异，但流程基本一致。

### 开启开发者选项

手机上操作：

1. 打开「设置」。
2. 找到「关于手机」或「我的设备」。
3. 找到「版本号」「软件版本」或「MIUI / HarmonyOS / ColorOS 版本」。
4. 连续点击 7 次。
5. 如果提示输入锁屏密码，输入即可。
6. 看到「你已处于开发者模式」或类似提示。

### 开启 USB 调试

手机上操作：

1. 回到「设置」。
2. 搜索「开发者选项」。
3. 进入「开发者选项」。
4. 开启「USB 调试」。
5. 如果有「USB 安装」「允许通过 USB 安装应用」「USB 调试（安全设置）」等选项，也建议开启。

### 连接电脑

1. 使用支持数据传输的 USB 线连接手机和电脑。
2. 手机通知栏中把 USB 用途改为「文件传输」或「传输文件」。
3. 手机上弹出「是否允许 USB 调试」时，勾选「一律允许使用这台计算机进行调试」，再点「允许」。

如果没有弹窗，先拔掉 USB 线重新插入，或者执行：

```powershell
adb kill-server
adb start-server
adb devices -l
```

## 第 11 步：确认电脑识别手机

执行：

```powershell
adb devices -l
```

可能看到 3 种情况：

| 输出状态 | 含义 | 怎么处理 |
| --- | --- | --- |
| `device` | 手机已授权，可以调试 | 可以继续执行 `flutter run` |
| `unauthorized` | 手机连接了，但未授权 | 看手机弹窗，点击允许；没有弹窗就重新插线 |
| 空列表 | 电脑没识别到手机 | 检查 USB 线、USB 模式、手机驱动、开发者选项 |

正常示例：

```text
List of devices attached
ABCDEF123456 device product:xxx model:xxx device:xxx transport_id:1
```

未授权示例：

```text
List of devices attached
ABCDEF123456 unauthorized
```

空列表示例：

```text
List of devices attached
```

如果一直是空列表：

1. 换一根确认能传文件的 USB 线。
2. 换一个电脑 USB 口。
3. 手机 USB 模式选择「文件传输」。
4. Windows 设备管理器中检查是否缺少手机厂商驱动。
5. 在手机开发者选项中点击「撤销 USB 调试授权」，然后重新插线授权。

## 第 12 步：运行 Flutter 项目到真机

进入你的 Flutter 项目目录。

示例：

```powershell
cd D:\Code\your_flutter_app
```

如果你不知道项目目录是不是 Flutter 项目，看目录下是否有：

```text
pubspec.yaml
lib\
android\
```

恢复依赖：

```powershell
flutter pub get
```

检查代码：

```powershell
flutter analyze
```

运行测试（如果项目有测试）：

```powershell
flutter test
```

查看 Flutter 能识别哪些设备：

```powershell
flutter devices
```

如果只连接一台 Android 手机，直接运行：

```powershell
flutter run
```

如果有多台设备，先从 `flutter devices` 里复制设备 ID，再指定运行：

```powershell
flutter run -d <device-id>
```

例如：

```powershell
flutter run -d ABCDEF123456
```

首次运行会比较慢，因为 Gradle 需要下载依赖和编译 Android 工程。

成功后，手机上会自动安装并打开 App，终端中会停在调试会话。

## 第 13 步：调试时怎么操作

`flutter run` 运行后，不要马上关闭 PowerShell。这个窗口就是调试控制台。

常用快捷键：

| 快捷键 | 作用 | 什么时候用 |
| --- | --- | --- |
| `r` | Hot reload | 改了页面、颜色、文案、普通 Dart 代码 |
| `R` | Hot restart | 改了初始化逻辑、全局状态、依赖注入 |
| `h` | 查看帮助 | 忘记快捷键 |
| `q` | 退出调试 | 不调试了 |

常见操作流程：

1. 执行 `flutter run`。
2. 手机打开 App。
3. 修改 Dart 代码。
4. 回到 PowerShell，按 `r`。
5. 手机界面刷新。

如果按 `r` 没生效，按 `R`。如果仍然不生效，退出后重新执行：

```powershell
flutter run
```

## 第 14 步：查看日志

查看 Flutter 日志：

```powershell
flutter logs
```

查看 Android 系统日志：

```powershell
adb logcat
```

如果日志太多，可以先清空旧日志：

```powershell
adb logcat -c
adb logcat
```

停止日志输出：

```text
Ctrl + C
```

## 第 15 步：构建和安装 Debug APK

如果不想用 `flutter run`，也可以先生成 APK，再手动安装到手机。

构建 Debug APK：

```powershell
flutter build apk --debug
```

生成文件通常在：

```text
build\app\outputs\flutter-apk\app-debug.apk
```

安装到手机：

```powershell
adb install -r .\build\app\outputs\flutter-apk\app-debug.apk
```

参数说明：

- `adb install`：安装 APK。
- `-r`：覆盖安装，不需要先卸载旧版本。

如果安装失败并提示签名或版本冲突，可以先卸载手机上的旧 App，再安装。

## 常见问题

### `flutter` 不是内部或外部命令

原因：`D:\Soft\flutter\bin` 没有加入 Path，或者当前 PowerShell 还没刷新环境变量。

处理：

```powershell
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
flutter --version
```

如果仍然失败，重新打开 PowerShell。

### `sdkmanager` 不是内部或外部命令

原因：Android Command-line Tools 没解压到正确目录，或者 Path 没配置。

检查：

```powershell
Test-Path D:\Soft\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat
echo $env:ANDROID_SDK_ROOT
where.exe sdkmanager
```

正确时，`where.exe sdkmanager` 应该能看到类似路径：

```text
D:\Soft\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat
```

### `flutter doctor` 找不到 Android SDK

执行：

```powershell
flutter config --android-sdk D:\Soft\Android\Sdk
flutter doctor -v
```

同时确认：

```powershell
echo $env:ANDROID_SDK_ROOT
echo $env:ANDROID_HOME
```

### `adb devices` 是空列表

优先检查硬件和手机设置：

1. USB 线是否支持数据传输。
2. 手机 USB 模式是否是「文件传输」。
3. 手机是否开启「USB 调试」。
4. 手机是否弹出授权框。
5. Windows 是否缺少手机厂商驱动。

然后重启 ADB：

```powershell
adb kill-server
adb start-server
adb devices -l
```

### `adb devices` 显示 `unauthorized`

说明手机没授权当前电脑。

处理：

1. 解锁手机屏幕。
2. 查看是否有「允许 USB 调试」弹窗。
3. 勾选「一律允许使用这台计算机进行调试」。
4. 点击「允许」。

如果没有弹窗：

1. 拔掉 USB 线。
2. 手机开发者选项里点击「撤销 USB 调试授权」。
3. 重新插线。
4. 再执行 `adb devices -l`。

### 首次 `flutter run` 或 `flutter build apk` 很慢

首次构建会下载 Gradle 和 Maven 依赖，慢是正常的。

如果超过 10 到 15 分钟没有明显进展，用详细日志查看卡在哪里：

```powershell
flutter build apk --debug -v
```

如果确认卡在 Maven / Gradle 依赖下载，可以考虑配置 Gradle 镜像。镜像会影响整个团队的依赖解析来源，建议团队统一确认后再配置。

### 手机提示禁止 USB 安装

部分国产 Android 系统需要额外开启：

- USB 安装
- 允许通过 USB 安装应用
- USB 调试（安全设置）
- 安装未知来源应用

这些选项通常在「开发者选项」或「安全」设置里。

## 最小验证清单

完成配置后，至少确认下面命令能跑通：

```powershell
$env:Path = (([Environment]::GetEnvironmentVariable('Path', 'Machine')), ([Environment]::GetEnvironmentVariable('Path', 'User'))) -join ';'
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
$env:ANDROID_SDK_ROOT = [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User')
$env:ANDROID_HOME = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User')
```

```powershell
flutter --version
dart --version
java -version
sdkmanager --version
adb version
flutter doctor -v
adb devices -l
flutter devices
```

如果已经连接并授权 Android 手机，还要确认：

```powershell
cd D:\Code\your_flutter_app
flutter pub get
flutter run
```

成功标准：

- `flutter doctor -v` 中 Android toolchain 通过。
- `adb devices -l` 能看到手机，状态是 `device`。
- `flutter devices` 能看到 Android 手机。
- `flutter run` 能把 App 安装并启动到手机。

## 不安装 Android Studio 的说明

本文方案只安装 Android SDK 命令行工具，不安装 Android Studio。

这种方式已经足够完成：

- 真机识别。
- Flutter 项目运行。
- Debug APK 构建。
- APK 安装。
- 基础日志查看。

如果以后需要图形化 SDK Manager、模拟器、Logcat 面板、布局检查器或完整 IDE，再安装 Android Studio。

## 本机示例结果

以下只是一次配置后的参考结果，不是所有机器都必须完全一样：

- Flutter SDK：`D:\Soft\flutter`
- Android SDK：`D:\Soft\Android\Sdk`
- Java：`D:\Program Files\Microsoft Visual Studio\Shared\Android\openjdk\jdk-21.0.8`
- `flutter doctor -v`：Android toolchain 通过，Android SDK version `36.0.0`
- `flutter analyze`：通过
- `flutter test`：通过
- 未连接手机时，`adb devices -l` 只显示空设备列表
