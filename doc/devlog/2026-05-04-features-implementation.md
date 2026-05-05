# 2026-05-04 功能实现：临期提醒、CSV导入导出、高级搜索

## 背景
用户要求实现以下功能：
1. 临期提醒小红点：有即将过期物品时显示提醒，点击跳转到临期界面
2. 改为CSV导入导出：替换原有的Excel导出功能
3. 高级搜索：支持多条件筛选功能

## 变更内容

### 1. 临期提醒小红点功能

#### 新增文件
- `Services/IPreferencesService.cs` - 偏好设置服务接口
- `Services/PreferencesService.cs` - 偏好设置服务实现

#### 修改文件
**AppShell.xaml**
- 添加标题栏视图（Shell.TitleView）
- 添加通知按钮（🔔/🔴）
- 设置按钮样式和点击事件

**AppShell.xaml.cs**
- 注入 IDataService 和 IPreferencesService
- 实现 `InitializeNotificationBadgeAsync()` 方法：检查3天内过期的物品
- 实现 `CheckExpiryNotificationsAsync()` 方法：更新通知图标状态
- 实现 `OnNotificationClicked()` 方法：标记已读并跳转到临期页面
- 重写 `OnAppearing()` 方法：页面出现时检查临期物品

**MauiProgram.cs**
- 注册 IPreferencesService 为单例服务

#### 功能说明
- 应用启动时自动检查3天内过期的物品
- 有临期物品时显示红色图标（🔴），无临期物品显示普通图标（🔔）
- 点击通知图标后标记为已读，图标变为普通状态
- 点击后跳转到临期页面
- 每次页面出现时重新检查临期状态

### 2. CSV导入导出功能

#### 修改文件
**Services/IDataService.cs**
- 移除 `ExportToExcelAsync()` 方法
- 添加 `ExportToCsvAsync()` 方法
- 添加 `ImportFromCsvAsync()` 方法

**Services/SqliteDataService.cs**
- 移除 ClosedXML using 语句
- 移除 `ExportToExcelAsync()` 实现
- 实现 `ExportToCsvAsync()` 方法：
  - 导出字段：物品名字、品牌、分类、购买日期、购买价格、保质期、是否显示日均成本、备注、存放位置、数量
  - 使用UTF-8编码
  - CSV字段转义处理（逗号、引号、换行）
- 实现 `ImportFromCsvAsync()` 方法：
  - 解析CSV文件（支持引号转义）
  - 验证CSV头格式
  - 按行导入数据
  - 返回成功/失败统计和错误信息
- 实现 `ParseCsvLine()` 辅助方法：解析CSV行

**ViewModels/StorageViewModel.cs**
- 重命名 `ExportExcelAsync` 为 `ExportCsvAsync`
- 调用 `ExportToCsvAsync()` 而非 `ExportToExcelAsync()`
- 新增 `ImportCsvAsync()` 命令：
  - 使用 FilePicker 选择CSV文件
  - 调用导入服务
  - 显示导入结果（成功/失败统计、错误信息）

**Views/StoragePage.xaml**
- 将"导出 Excel"按钮文本改为"导出 CSV"
- 将命令绑定从 `ExportExcelCommand` 改为 `ExportCsvCommand`
- 添加"导入 CSV"按钮
- 设置文件类型过滤器为.csv

**MyItems.csproj**
- 移除 ClosedXML 包引用

#### CSV格式规范
**导出格式**：
```csv
物品名字,品牌,分类,购买日期,购买价格,保质期,是否显示日均成本,备注,存放位置,数量
洗发水,海飞丝,日用品,2024-01-01,29.90,2025-12-31,否,丰盈款,卫生间,1
```

**导入要求**：
- 必须包含完整的CSV头
- 分类必须已存在于数据库中
- 日期格式：yyyy-MM-dd
- 价格格式：数字
- 是否显示日均成本：是/否
- 存放位置和备注可为空

### 3. 高级搜索功能

#### 新增文件
- `Models/SearchFilter.cs` - 搜索过滤器模型
- `Views/AdvancedSearchPage.xaml` - 高级搜索页面
- `Views/AdvancedSearchPage.xaml.cs` - 高级搜索页面代码隐藏
- `ViewModels/AdvancedSearchViewModel.cs` - 高级搜索视图模型
- `Converters/DecimalToStringConverter.cs` - Decimal到String转换器
- `Helpers/SearchFilterHelper.cs` - 搜索过滤器传递辅助类

#### 修改文件
**ViewModels/ItemLibraryViewModel.cs**
- 添加 `AdvancedSearchFilter` 属性
- 添加 `OpenAdvancedSearchCommand` 命令
- 添加 `ApplySearchFilter()` 方法
- 修改 `LoadDataAsync()` 方法：应用高级搜索过滤器

**Views/ItemLibraryPage.xaml**
- 在设置菜单中添加"🔍 高级搜索"按钮

**Views/ItemLibraryPage.xaml.cs**
- 重写 `OnNavigatedTo()` 方法
- 处理从高级搜索返回的过滤器

**MauiProgram.cs**
- 注册 `AdvancedSearchViewModel`
- 注册 `AdvancedSearchPage`

**AppShell.xaml.cs**
- 注册 "advancedsearch" 路由

#### 高级搜索功能支持
- **关键词搜索**：物品名称、品牌
- **价格区间**：最低价格、最高价格
- **购买日期**：起始日期、结束日期
- **保质期**：起始日期、结束日期
- **分类筛选**：选择特定分类
- **保质期状态**：
  - 只显示有保质期的物品
  - 只显示临期/已过期
  - 只显示已过期

#### 搜索逻辑
- 所有筛选条件为"与"关系（同时满足）
- 关键词搜索支持物品名称和品牌
- 价格区间支持仅设置最低价或最高价
- 日期区间支持仅设置起始日期或结束日期
- 分类筛选可选择特定分类或全部分类
- 支持重置所有筛选条件

## 技术要点

### 1. 服务依赖注入
- 使用单例模式注册 `IDataService` 和 `IPreferencesService`
- 使用瞬态模式注册 ViewModels 和 Pages
- 在构造函数中注入依赖服务

### 2. 数据持久化
- 使用 Preferences API 保存用户偏好设置
- 临期通知状态持久化存储
- 主题偏好持久化存储（之前实现）

### 3. CSV处理
- UTF-8编码确保中文正常显示
- 字段转义处理特殊字符（逗号、引号、换行）
- 错误处理和统计信息收集

### 4. 导航参数传递
- 使用静态辅助类 `SearchFilterHelper` 传递复杂对象
- 避免了MAUI导航参数传递的限制

### 5. 动态UI更新
- 使用 `ObservableObject` 和属性变化通知
- 搜索条件实时应用
- 通知图标状态动态更新

## 测试验证

### 编译验证
- Windows 平台编译成功，无错误
- 仅有一些可空引用警告（不影响功能）

### 功能验证建议

**临期提醒功能**：
1. 创建3天内过期的物品，检查右上角是否显示红色图标
2. 点击通知图标，确认跳转到临期页面
3. 确认点击后图标变为普通状态
4. 删除所有临期物品，确认图标保持普通状态

**CSV导入导出**：
1. 导出CSV文件，用文本编辑器查看格式是否正确
2. 修改CSV文件内容，测试导入功能
3. 测试分类不存在时的错误处理
4. 测试CSV格式错误的处理
5. 测试特殊字符（逗号、引号、换行）的转义

**高级搜索**：
1. 测试单个筛选条件
2. 测试多个筛选条件组合
3. 测试价格区间（仅最低价、仅最高价、完整区间）
4. 测试日期区间（仅起始、仅结束、完整区间）
5. 测试重置功能
6. 测试保质期状态筛选

## 风险与限制

### 已知限制
- Android/iOS 平台未测试（缺少相应环境）
- CSV导入依赖分类已存在，不会自动创建分类
- 临期提醒仅检查3天内过期的物品
- 高级搜索不提供分页，大量数据可能影响性能

### 潜在风险
- CSV导入时分类不匹配会导致数据丢失
- 大量物品时高级搜索可能较慢
- 临期检查在每次页面出现时执行，可能有性能影响

## 后续优化建议

1. **性能优化**：为高级搜索添加数据库索引
2. **用户体验**：添加保存搜索方案功能
3. **导入增强**：支持自动创建不存在的分类
4. **通知增强**：添加推送通知支持
5. **搜索优化**：添加搜索历史记录
6. **CSV增强**：支持批量导入图片路径

## 文件变更统计

### 新增文件：8个
- Services/IPreferencesService.cs
- Services/PreferencesService.cs
- Models/SearchFilter.cs
- Views/AdvancedSearchPage.xaml
- Views/AdvancedSearchPage.xaml.cs
- ViewModels/AdvancedSearchViewModel.cs
- Converters/DecimalToStringConverter.cs
- Helpers/SearchFilterHelper.cs

### 修改文件：12个
- AppShell.xaml
- AppShell.xaml.cs
- MauiProgram.cs
- Services/IDataService.cs
- Services/SqliteDataService.cs
- ViewModels/StorageViewModel.cs
- ViewModels/ItemLibraryViewModel.cs
- Views/StoragePage.xaml
- Views/ItemLibraryPage.xaml
- Views/ItemLibraryPage.xaml.cs
- MyItems.csproj
- App.xaml.cs (之前修改的主题切换)

### 删除依赖：1个
- ClosedXML 包

## 总结

本次开发成功实现了三个主要功能：
1. ✅ 临期提醒小红点：提高用户对临期物品的关注度
2. ✅ CSV导入导出：提升数据管理的灵活性和可移植性
3. ✅ 高级搜索：增强数据筛选能力，提升用户体验

所有功能均遵循现有架构规范，使用了MVVM模式、依赖注入、数据绑定等最佳实践。编译通过无错误，为后续测试和优化奠定了基础。
