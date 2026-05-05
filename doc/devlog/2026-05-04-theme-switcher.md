# 2026-05-04 主题切换功能实现

## 背景
用户反馈项目缺少主题切换功能，并且暗黑模式下一些图标看不清。

## 变更内容

### 1. 新增主题切换功能

#### 文件修改

**AboutViewModel.cs**
- 新增主题选择相关属性：`SelectedThemeIndex`、`ThemeOptions`
- 新增主题偏好设置常量：`ThemePreferenceKey`
- 实现 `LoadThemePreference()` 方法：从 Preferences 读取用户选择的主题
- 实现 `OnSelectedThemeIndexChanged()` 方法：保存主题选择并应用
- 实现 `ApplyTheme()` 方法：根据选择设置应用主题（跟随系统/浅色/深色）

**AboutPage.xaml**
- 在版本更新卡片前新增主题设置卡片
- 添加 Picker 控件供用户选择主题
- 主题选项：跟随系统、浅色模式、深色模式

**App.xaml.cs**
- 新增 `ThemePreferenceKey` 常量
- 重构构造函数：新增 `LoadAndApplyTheme()` 方法
- 实现 `LoadAndApplyTheme()` 方法：
  - 应用启动时读取用户保存的主题偏好
  - 根据用户选择设置 `UserAppTheme` 属性
  - 确保用户选择的主题在启动时立即生效

### 2. 修复暗黑模式下图标看不清问题

#### App.xaml.cs
- 修改暗黑模式下文本颜色：
  - `AppTextMutedColor`: 从 `#64748B` 改为 `#94A3B8`（提高亮度）
  - `AppTextDisabledColor`: 从 `#475569` 改为 `#94A3B8`（提高亮度）

#### AppShell.xaml
- 修改 TabBar 颜色设置：
  - `TabBarForegroundColor`: 从 `AppTextMutedColor` 改为 `AppTextColor`（提高对比度）
  - `TabBarUnselectedColor`: 从 `AppTextDisabledColor` 改为 `AppTextSecondaryColor`（提高对比度）

## 技术要点

### 主题持久化
- 使用 `Preferences.Set()` / `Preferences.Get()` 保存和读取用户主题选择
- 键名：`app_theme`，值：0（跟随系统）、1（浅色）、2（深色）

### 主题应用
- 通过 `Application.Current.UserAppTheme` 属性设置应用主题
- 使用 `AppTheme.Unspecified` 跟随系统主题
- 使用 `AppTheme.Light` / `AppTheme.Dark` 强制使用浅色/深色主题

### 动态颜色
- 所有颜色使用 `DynamicResource` 引用，确保主题切换时自动更新
- `App.xaml.cs` 中的 `ApplyTheme()` 方法根据当前主题更新颜色资源

## 用户体验

### 访问路径
用户可通过以下路径访问主题设置：
1. 打开应用 → 进入"物品库"标签
2. 点击右上角菜单按钮（☰）
3. 选择"ℹ 关于"
4. 在关于页面顶部找到"主题设置"卡片
5. 通过下拉选择器切换主题

### 即时生效
- 选择主题后立即生效，无需重启应用
- 主题选择会被保存，下次启动应用时自动应用

## 测试验证

### 编译验证
- Windows 平台编译成功，无错误无警告

### 视觉验证建议
1. 测试三种主题模式：跟随系统、浅色、深色
2. 验证 TabBar 图标在不同主题下的可读性
3. 验证设置页面的主题选择器功能
4. 验证应用重启后主题选择是否被保存

## 风险与限制

### 已知限制
- Android 平台未测试（缺少 Android SDK 环境）
- iOS 平台未测试

### 潜在风险
- 无明显风险，主题切换是标准 MAUI 功能

## 后续优化建议

1. 考虑将主题设置移至独立的设置页面，如果未来设置项增多
2. 考虑在更多位置添加主题切换入口（如设置菜单）
3. 考虑添加更多主题选项（如高对比度模式）
