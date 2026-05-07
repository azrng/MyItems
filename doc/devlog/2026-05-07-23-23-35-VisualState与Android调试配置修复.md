# VisualState 与 Android 调试配置修复

## 本次目标

修复 XAML 中 `Button.VisualStateManager.VisualStateGroups` 标签无效的问题，并补齐 Android 调试所需的 Debug 符号配置。

## 核心改动

- 将 `CategoryPage.xaml`、`ItemLibraryPage.xaml`、`StoragePage.xaml` 中错误的 `Button.VisualStateManager.VisualStateGroups` 改为 MAUI 支持的 `VisualStateManager.VisualStateGroups`。
- 在 `MyItems.csproj` 的 Debug 配置中启用 `DebugSymbols`、`DebugType=portable` 和 `AndroidIncludeDebugSymbols`。

## 修改文件

- `src/MyItems/Views/CategoryPage.xaml`
- `src/MyItems/Views/ItemLibraryPage.xaml`
- `src/MyItems/Views/StoragePage.xaml`
- `src/MyItems/MyItems.csproj`

## 校验情况

- 已执行：`dotnet build .\src\MyItems\MyItems.csproj -f net10.0-windows10.0.19041.0 --no-restore`
- 结果：构建通过，0 个错误。
- 已执行：`dotnet build .\src\MyItems\MyItems.csproj -f net10.0-android --no-restore`
- 结果：当前环境缺少 Android SDK，仍失败于 `XA5300`，未进入 Android 真实编译阶段。

## 风险或遗留项

- Android 调试符号配置已补齐，但需要在安装 Android SDK 的环境中重新验证真机调试。
- 仍有既有 `MVVMTK0045` warning，本次未处理。
