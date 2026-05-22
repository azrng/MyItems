## [ERR-20260508-001] dotnet_build_after_workload_restore

**Logged**: 2026-05-08T13:55:03+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
`dotnet workload restore` 成功后，项目构建仍可能因缺少 `project.assets.json` 在 `--no-restore` 下失败。

### Error
```text
error NETSDK1004: 找不到资产文件“...\obj\project.assets.json”。运行 NuGet 包还原以生成此文件。
```

### Context
- 先执行 `dotnet workload restore .\src\MyItems\MyItems.csproj` 安装 MAUI workload。
- 随后立即执行 `dotnet build .\src\MyItems\MyItems.csproj -f net10.0-windows10.0.19041.0 --no-restore`。

### Suggested Fix
在 workload restore 后执行一次项目级 NuGet restore，再使用 `--no-restore` 构建：
```powershell
dotnet restore .\src\MyItems\MyItems.csproj -p:TargetFramework=net10.0-windows10.0.19041.0
dotnet build .\src\MyItems\MyItems.csproj -f net10.0-windows10.0.19041.0 --no-restore
```

### Metadata
- Reproducible: yes
- Related Files: src/MyItems/MyItems.csproj

### Resolution
- **Resolved**: 2026-05-08T13:55:03+08:00
- **Notes**: 已通过项目级 restore 生成资产文件，随后 Windows target 构建通过。

---

## [ERR-20260522-001] flutter_and_gradle_verification_unavailable

**Logged**: 2026-05-22T15:48:17+08:00
**Priority**: medium
**Status**: pending
**Area**: tests

### Summary
Flutter 测试命令不可用，Android Gradle wrapper 下载 Gradle 发行包时证书校验失败。

### Error
```text
flutter : The term 'flutter' is not recognized as the name of a cmdlet, function, script file, or operable program.

Exception in thread "main" javax.net.ssl.SSLHandshakeException:
PKIX path building failed: unable to find valid certification path to requested target
```

### Context
- Attempted `flutter test test/app_store_test.dart test/navigation_test.dart` from repo root.
- Attempted `.\gradlew.bat :app:compileDebugKotlin` from `android/`.
- `Get-Command flutter,dart,fvm` returned no available executables.
- Gradle wrapper tried downloading `https://mirrors.cloud.tencent.com/gradle/gradle-8.9-all.zip`.

### Suggested Fix
Install/configure Flutter SDK on PATH and either fix the Java trust store for the Tencent Gradle mirror or use a reachable Gradle distribution URL with a trusted certificate.

### Metadata
- Reproducible: yes
- Related Files: android/gradle/wrapper/gradle-wrapper.properties, pubspec.yaml

---
