# MyItems（我的物品）

个人物品管理应用，基于 .NET MAUI，支持 Android 和 Windows 平台。

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
