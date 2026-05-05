using MyItems.Enums;
using MyItems.Helpers;
using MyItems.Models;
using MyItems.Models.DTOs;
using SQLite;

namespace MyItems.Services;

public class SqliteDataService : IDataService
{
    private readonly string _dbPath;
    private readonly SQLiteAsyncConnection _db;
    private readonly SemaphoreSlim _initLock = new(1, 1);
    private bool _initialized;

    public SqliteDataService(string dbPath)
    {
        _dbPath = dbPath;
        _db = new SQLiteAsyncConnection(dbPath);
    }

    public async Task InitializeAsync()
    {
        if (_initialized) return;
        await _initLock.WaitAsync();
        try
        {
            if (_initialized) return;

            var version = await GetDbVersionInternalAsync();
            try
            {
                await RunMigrationsAsync(version);
            }
            catch
            {
                // 迁移失败仍允许进入系统，用户可在存储管理清空数据
            }

            await EnsureRuntimeSchemaAsync();

            _initialized = true;
        }
        finally
        {
            _initLock.Release();
        }
    }

    private async Task EnsureRuntimeSchemaAsync()
    {
        var itemColumns = await _db.QueryAsync<TableColumnInfo>("PRAGMA table_info(\"Items\")");
        if (itemColumns.Count > 0 && itemColumns.All(c => !string.Equals(c.Name, nameof(Item.Name), StringComparison.OrdinalIgnoreCase)))
        {
            await _db.ExecuteAsync("ALTER TABLE \"Items\" ADD COLUMN \"Name\" text NOT NULL DEFAULT ''");
        }
    }

    public sealed class TableColumnInfo
    {
        [Column("name")]
        public string Name { get; set; } = string.Empty;
    }

    private async Task<int> GetDbVersionInternalAsync()
    {
        try
        {
            var logs = await _db.Table<VersionLog>().OrderByDescending(v => v.Version).ToListAsync();
            return logs.Count > 0 ? logs[0].Version : 0;
        }
        catch
        {
            return 0;
        }
    }

    private async Task RunMigrationsAsync(int currentVersion)
    {
        var assembly = typeof(SqliteDataService).Assembly;
        var resourcePrefix = $"{assembly.GetName().Name}.Migrations.";

        var resources = assembly.GetManifestResourceNames()
            .Where(r => r.StartsWith(resourcePrefix) && r.EndsWith(".sql"))
            .Select(r =>
            {
                var fileName = r.Substring(resourcePrefix.Length);
                // Format: V{version}__{description}.sql
                var parts = Path.GetFileNameWithoutExtension(fileName).Split("__", 2);
                var version = int.Parse(parts[0].TrimStart('V', 'v'));
                var desc = parts.Length > 1 ? parts[1].Replace('_', ' ') : string.Empty;
                return (version, desc, resource: r);
            })
            .Where(m => m.version > currentVersion)
            .OrderBy(m => m.version)
            .ToList();

        foreach (var (version, desc, resource) in resources)
        {
            using var stream = assembly.GetManifestResourceStream(resource);
            using var reader = new StreamReader(stream!);
            var sql = await reader.ReadToEndAsync();

            var statements = sql.Split(';')
                .Select(s =>
                {
                    var lines = s.Split('\n')
                        .Where(line => !line.TrimStart().StartsWith("--"));
                    return string.Join('\n', lines).Trim();
                })
                .Where(s => !string.IsNullOrWhiteSpace(s)
                    && !s.TrimStart().StartsWith("--"))
                .ToList();

            if (statements.Count == 0) continue;

            await _db.RunInTransactionAsync(tran =>
            {
                foreach (var statement in statements)
                    tran.Execute(statement);
                tran.Insert(new VersionLog { Version = version, Description = desc });
            });
        }
    }

    private async Task EnsureInitializedAsync()
    {
        if (!_initialized)
            await InitializeAsync();
    }

    #region Category

    public async Task<List<Category>> GetCategoriesAsync()
    {
        await EnsureInitializedAsync();
        return await _db.Table<Category>().OrderBy(c => c.SortOrder).ToListAsync();
    }

    public async Task<int> SaveCategoryAsync(Category category)
    {
        await EnsureInitializedAsync();
        var existing = await _db.Table<Category>().Where(c => c.Id == category.Id).FirstOrDefaultAsync();
        if (existing is not null)
            return await _db.UpdateAsync(category);

        return await _db.InsertAsync(category);
    }

    public async Task<int> DeleteCategoryAsync(Category category)
    {
        await EnsureInitializedAsync();
        return await _db.DeleteAsync(category);
    }

    public async Task<bool> CategoryHasItemsAsync(Guid categoryId)
    {
        await EnsureInitializedAsync();
        var count = await _db.Table<Item>()
            .Where(i => i.CategoryId == categoryId && !i.IsArchived)
            .CountAsync();
        return count > 0;
    }

    #endregion

    #region Item

    public async Task<List<Item>> GetItemsAsync()
    {
        await EnsureInitializedAsync();
        return await _db.Table<Item>().Where(i => !i.IsArchived).ToListAsync();
    }

    public async Task<Item?> GetItemByIdAsync(Guid itemId)
    {
        await EnsureInitializedAsync();
        return await _db.Table<Item>().Where(i => i.Id == itemId).FirstOrDefaultAsync();
    }

    public async Task<Guid> SaveItemAsync(Item item)
    {
        await EnsureInitializedAsync();
        await _db.InsertOrReplaceAsync(item);
        return item.Id;
    }

    public async Task<int> DeleteItemAsync(Guid itemId)
    {
        await EnsureInitializedAsync();
        return await _db.ExecuteAsync("DELETE FROM Items WHERE Id = ?", itemId);
    }

    #endregion

    #region Core Data Loader

    private async Task<(List<Item> Items, Dictionary<Guid, Category> CatLookup)> LoadCoreDataAsync()
    {
        await EnsureInitializedAsync();

        var items = await _db.Table<Item>().Where(i => !i.IsArchived).ToListAsync();
        var categories = await _db.Table<Category>().OrderBy(c => c.SortOrder).ToListAsync();
        var catLookup = categories.ToDictionary(c => c.Id);

        return (items, catLookup);
    }

    private static ItemDisplayDto ToItemDisplayDto(Item item, Category? category)
    {
        var expiryStatus = StatusHelper.CalculateExpiryStatus(item.ExpiryDate);

        return new ItemDisplayDto
        {
            ItemId = item.Id,
            ItemName = item.Name,
            ItemIcon = item.Icon,
            Brand = item.Brand,
            Barcode = item.Barcode,
            CategoryId = item.CategoryId,
            CategoryName = category?.Name ?? string.Empty,
            CategoryIcon = category?.Icon,
            PurchaseDate = item.PurchaseDate,
            PurchasePrice = item.PurchasePrice,
            ExpiryDate = item.ExpiryDate,
            Location = item.DefaultLocation,
            Quantity = item.Quantity,
            TrackDailyCost = item.TrackDailyCost,
            Notes = item.Notes,
            CreatedAt = item.CreatedAt,
            ExpiryStatus = expiryStatus,
            ExpiryStatusText = StatusHelper.GetExpiryStatusText(expiryStatus, item.ExpiryDate),
            HoldingDays = StatusHelper.GetHoldingDays(item.PurchaseDate),
            DailyCost = StatusHelper.CalculateDailyCost(item.PurchasePrice, item.Quantity, item.PurchaseDate),
            DailyCostText = item.TrackDailyCost ? StatusHelper.GetDailyCostText(item.PurchasePrice, item.Quantity, item.PurchaseDate) : string.Empty,
            HoldingText = StatusHelper.GetHoldingText(item.PurchaseDate),
        };
    }

    #endregion

    #region DTO Queries

    public async Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync()
    {
        var (items, catLookup) = await LoadCoreDataAsync();
        return items.Select(item =>
        {
            catLookup.TryGetValue(item.CategoryId, out var category);
            return ToItemDisplayDto(item, category);
        }).ToList();
    }

    public async Task<ItemDisplayDto?> GetItemDisplayDtoByIdAsync(Guid itemId)
    {
        await EnsureInitializedAsync();
        var item = await _db.Table<Item>().Where(i => i.Id == itemId).FirstOrDefaultAsync();
        if (item is null) return null;

        var category = await _db.Table<Category>().Where(c => c.Id == item.CategoryId).FirstOrDefaultAsync();
        return ToItemDisplayDto(item, category);
    }

    public async Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync()
    {
        var (items, catLookup) = await LoadCoreDataAsync();
        var dtos = items.Select(item =>
        {
            catLookup.TryGetValue(item.CategoryId, out var category);
            return ToItemDisplayDto(item, category);
        }).ToList();

        return Enum.GetValues<ExpiryStatus>()
            .Select(status =>
            {
                var groupItems = dtos
                    .Where(d => d.ExpiryStatus == status)
                    .OrderBy(d => d.ExpiryDate)
                    .ToList();

                return new ExpiryGroupDto
                {
                    Status = status,
                    Title = StatusHelper.GetGroupTitle(status),
                    StatusIcon = StatusHelper.GetGroupIcon(status),
                    Items = groupItems,
                    IsExpanded = status is ExpiryStatus.Expired or ExpiryStatus.Expiring,
                };
            })
            .Where(g => g.Items.Count > 0)
            .ToList();
    }

    public async Task<List<CategoryDto>> GetCategoryDtosAsync()
    {
        await EnsureInitializedAsync();
        var categories = await _db.Table<Category>().OrderBy(c => c.SortOrder).ToListAsync();

        return categories.Select(c => new CategoryDto
        {
            Id = c.Id,
            Name = c.Name,
            Icon = c.Icon,
            SortOrder = c.SortOrder,
            IsPreset = c.IsPreset,
            IsActive = c.IsActive,
        }).ToList();
    }

    public async Task<(decimal TotalSpent, int TotalItems, int ValidItems)> GetStatisticsAsync()
    {
        var (items, _) = await LoadCoreDataAsync();

        var totalItems = items.Count;
        decimal totalSpent = 0;
        var validCount = 0;

        foreach (var item in items)
        {
            var status = StatusHelper.CalculateExpiryStatus(item.ExpiryDate);
            if (status != ExpiryStatus.Expired)
            {
                totalSpent += (item.PurchasePrice ?? 0) * item.Quantity;
                validCount++;
            }
        }

        return (totalSpent, totalItems, validCount);
    }

    public async Task<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)> GetItemsWithStatisticsAsync()
    {
        var (items, catLookup) = await LoadCoreDataAsync();

        var dtos = items.Select(item =>
        {
            catLookup.TryGetValue(item.CategoryId, out var category);
            return ToItemDisplayDto(item, category);
        }).ToList();

        decimal totalSpent = 0;
        var validCount = 0;
        foreach (var item in items)
        {
            var status = StatusHelper.CalculateExpiryStatus(item.ExpiryDate);
            if (status != ExpiryStatus.Expired)
            {
                totalSpent += (item.PurchasePrice ?? 0) * item.Quantity;
                validCount++;
            }
        }

        return (dtos, totalSpent, items.Count, validCount);
    }

    #endregion

    #region CSV Import/Export

    public async Task<string> ExportToCsvAsync()
    {
        await EnsureInitializedAsync();
        var items = await _db.Table<Item>().Where(i => !i.IsArchived).ToListAsync();
        var categories = await _db.Table<Category>().ToListAsync();
        var catLookup = categories.ToDictionary(c => c.Id);

        var filePath = Path.Combine(FileSystem.CacheDirectory, $"MyItems_{DateTime.Now:yyyyMMdd_HHmmss}.csv");

        using var writer = new StreamWriter(filePath, false, System.Text.Encoding.UTF8);

        // 写入CSV头
        await writer.WriteLineAsync("物品名字,品牌,分类,购买日期,购买价格,保质期,是否显示日均成本,备注,存放位置,数量");

        // 写入数据
        foreach (var item in items)
        {
            catLookup.TryGetValue(item.CategoryId, out var cat);

            // CSV字段转义，处理包含逗号、引号、换行的字段
            var escapeCsv = (string s) =>
            {
                if (string.IsNullOrEmpty(s)) return string.Empty;
                if (s.Contains(',') || s.Contains('"') || s.Contains('\n') || s.Contains('\r'))
                {
                    return $"\"{s.Replace("\"", "\"\"")}\"";
                }
                return s;
            };

            var line = string.Join(",",
                escapeCsv(item.Name),
                escapeCsv(item.Brand ?? string.Empty),
                escapeCsv(cat?.Name ?? string.Empty),
                escapeCsv(item.PurchaseDate?.ToString("yyyy-MM-dd") ?? string.Empty),
                escapeCsv(item.PurchasePrice?.ToString("F2") ?? string.Empty),
                escapeCsv(item.ExpiryDate?.ToString("yyyy-MM-dd") ?? string.Empty),
                escapeCsv(item.TrackDailyCost ? "是" : "否"),
                escapeCsv(item.Notes ?? string.Empty),
                escapeCsv(item.DefaultLocation ?? string.Empty),
                escapeCsv(item.Quantity.ToString())
            );

            await writer.WriteLineAsync(line);
        }

        return filePath;
    }

    public async Task<(int SuccessCount, int FailureCount, List<string> Errors)> ImportFromCsvAsync(string filePath)
    {
        await EnsureInitializedAsync();
        var categories = await _db.Table<Category>().ToListAsync();
        var catLookup = categories.ToDictionary(c => c.Name, c => c.Id);

        var successCount = 0;
        var failureCount = 0;
        var errors = new List<string>();

        try
        {
            using var reader = new StreamReader(filePath, System.Text.Encoding.UTF8);
            var headerLine = await reader.ReadLineAsync();

            if (string.IsNullOrWhiteSpace(headerLine))
            {
                return (0, 0, new List<string> { "CSV文件为空" });
            }

            var headers = headerLine.Split(',');
            var expectedHeaders = new[] { "物品名字", "品牌", "分类", "购买日期", "购买价格", "保质期", "是否显示日均成本", "备注", "存放位置", "数量" };

            // 验证CSV头
            if (!headers.SequenceEqual(expectedHeaders))
            {
                return (0, 0, new List<string> { "CSV格式不正确，请确保包含正确的列头" });
            }

            var lineNumber = 1;
            string? line;

            while ((line = await reader.ReadLineAsync()) != null)
            {
                lineNumber++;
                try
                {
                    var fields = ParseCsvLine(line);

                    if (fields.Length < 10)
                    {
                        errors.Add($"第{lineNumber}行：字段数量不足");
                        failureCount++;
                        continue;
                    }

                    var itemName = fields[0]?.Trim();
                    if (string.IsNullOrEmpty(itemName))
                    {
                        errors.Add($"第{lineNumber}行：物品名字不能为空");
                        failureCount++;
                        continue;
                    }

                    var categoryName = fields[2]?.Trim();
                    if (string.IsNullOrEmpty(categoryName) || !catLookup.TryGetValue(categoryName, out var categoryId))
                    {
                        errors.Add($"第{lineNumber}行：分类「{categoryName}」不存在，跳过此物品");
                        failureCount++;
                        continue;
                    }

                    var item = new Item
                    {
                        Id = Guid.NewGuid(),
                        Name = itemName,
                        Brand = string.IsNullOrWhiteSpace(fields[1]) ? null : fields[1].Trim(),
                        CategoryId = categoryId,
                        PurchaseDate = DateTime.TryParse(fields[3], out var purchaseDate) ? purchaseDate : null,
                        PurchasePrice = decimal.TryParse(fields[4], out var price) ? price : null,
                        ExpiryDate = DateTime.TryParse(fields[5], out var expiryDate) ? expiryDate : null,
                        TrackDailyCost = fields[6] == "是",
                        Notes = string.IsNullOrWhiteSpace(fields[7]) ? null : fields[7].Trim(),
                        DefaultLocation = string.IsNullOrWhiteSpace(fields[8]) ? null : fields[8].Trim(),
                        Quantity = int.TryParse(fields[9], out var qty) && qty > 0 ? qty : 1,
                        IsArchived = false,
                        CreatedAt = DateTime.Now,
                        UpdatedAt = DateTime.Now
                    };

                    await _db.InsertAsync(item);
                    successCount++;
                }
                catch (Exception ex)
                {
                    errors.Add($"第{lineNumber}行：{ex.Message}");
                    failureCount++;
                }
            }
        }
        catch (Exception ex)
        {
            errors.Add($"读取文件失败：{ex.Message}");
        }

        return (successCount, failureCount, errors);
    }

    private string[] ParseCsvLine(string line)
    {
        var fields = new List<string>();
        var current = new System.Text.StringBuilder();
        var inQuotes = false;

        foreach (var ch in line)
        {
            if (ch == '"')
            {
                if (inQuotes && current.Length > 0 && current[^1] == '"')
                {
                    current.Append('"');
                }
                else
                {
                    inQuotes = !inQuotes;
                }
            }
            else if (ch == ',' && !inQuotes)
            {
                fields.Add(current.ToString());
                current.Clear();
            }
            else
            {
                current.Append(ch);
            }
        }

        fields.Add(current.ToString());
        return fields.ToArray();
    }

    #endregion

    #region Testing

    public async Task SeedSampleDataAsync()
    {
        await EnsureInitializedAsync();

        var random = new Random(42);
        var categories = await GetCategoriesAsync();
        var locations = new[] { "冰箱上层", "冰箱下层", "厨房柜子", "卫生间", "卧室抽屉", "客厅柜子", "药箱", "书桌", "鞋柜", "阳台储物" };

        var foodItems = new[] { ("纯牛奶", "蒙牛"), ("酸奶", "伊利"), ("面包", "桃李"), ("方便面", "康师傅"), ("薯片", "乐事"), ("饼干", "奥利奥"), ("巧克力", "德芙"), ("果汁", "汇源"), ("可乐", "可口可乐"), ("矿泉水", "农夫山泉"), ("火腿肠", "双汇"), ("速冻水饺", "湾仔码头"), ("酱油", "海天"), ("醋", "恒顺"), ("食用油", "鲁花"), ("大米", "五常"), ("面粉", "金沙河"), ("鸡蛋", "正大"), ("豆腐", "祖名"), ("午餐肉", "梅林"), ("蜂蜜", "百花牌"), ("花生酱", "四季宝"), ("咖啡", "雀巢"), ("茶叶", "龙井"), ("麦片", "桂格"), ("奶粉", "飞鹤"), ("冰淇淋", "哈根达斯"), ("蛋糕", "好利来"), ("牛肉干", "科尔沁"), ("果脯", "百草味") };

        var cosmeticItems = new[] { ("洗面奶", "芙丽芳丝"), ("面霜", "科颜氏"), ("防晒霜", "安耐晒"), ("爽肤水", "兰蔻"), ("面膜", "御泥坊"), ("粉底液", "雅诗兰黛"), ("口红", "MAC"), ("睫毛膏", "美宝莲"), ("卸妆水", "贝德玛"), ("润唇膏", "曼秀雷敦"), ("洗发水", "飘柔"), ("护发素", "沙宣"), ("沐浴露", "舒肤佳"), ("身体乳", "凡士林"), ("护手霜", "欧舒丹"), ("眼霜", "雅诗兰黛"), ("精华液", "兰蔻"), ("散粉", "纪梵希"), ("眉笔", "植村秀"), ("香水", "迪奥") };

        var medicineItems = new[] { ("感冒药", "三九"), ("退烧药", "泰诺"), ("创可贴", "云南白药"), ("维生素", "汤臣倍健"), ("钙片", "钙尔奇"), ("眼药水", "乐敦"), ("止泻药", "蒙脱石散"), ("抗过敏药", "开瑞坦"), ("止咳糖浆", "急支糖浆"), ("碘伏", "稳健"), ("藿香正气水", "太极"), ("风油精", "白花"), ("胃药", "达喜"), ("消炎药", "阿莫西林"), ("口罩", "3M") };

        var dailyItems = new[] { ("纸巾", "维达"), ("洗衣液", "蓝月亮"), ("洗洁精", "立白"), ("垃圾袋", "妙洁"), ("保鲜膜", "克林莱"), ("电池", "南孚"), ("拖鞋", "无品牌"), ("毛巾", "洁丽雅"), ("牙刷", "欧乐B"), ("牙膏", "佳洁士"), ("香皂", "舒肤佳"), ("驱蚊液", "六神"), ("湿巾", "德佑"), ("收纳盒", "无品牌"), ("挂钩", "3M") };

        var electronicItems = new[] { ("显示器", "戴尔"), ("键盘", "罗技"), ("鼠标", "罗技"), ("耳机", "索尼"), ("充电线", "绿联"), ("充电宝", "小米"), ("移动硬盘", "西部数据"), ("U盘", "金士顿"), ("路由器", "TP-Link"), ("摄像头", "小米"), ("台灯", "飞利浦"), ("插线板", "公牛"), ("屏幕挂灯", "明基"), ("鼠标垫", "赛睿"), ("音响", "哈曼卡顿") };

        var categoryData = new[]
        {
            (categories[0].Id, foodItems, "\U0001F354"),
            (categories[1].Id, cosmeticItems, "\U0001F484"),
            (categories[2].Id, medicineItems, "\U0001F48A"),
            (categories[3].Id, dailyItems, "\U0001F9F4"),
            (categories[4].Id, electronicItems, "\U0001F4BB"),
        };

        var items = new List<Item>();

        foreach (var (catId, productNames, icon) in categoryData)
        {
            for (var i = 0; i < productNames.Length; i++)
            {
                var (name, brand) = productNames[i];
                var purchaseDaysAgo = random.Next(0, 90);
                var hasExpiry = random.Next(100) < 70;
                var trackDailyCost = random.Next(100) < 60;
                var price = random.Next(3, 500) + random.Next(10, 99) / 100m;

                items.Add(new Item
                {
                    Id = Guid.NewGuid(),
                    Name = name,
                    CategoryId = catId,
                    Brand = brand,
                    Icon = icon,
                    DefaultLocation = locations[random.Next(locations.Length)],
                    PurchaseDate = DateTime.Today.AddDays(-purchaseDaysAgo),
                    PurchasePrice = price,
                    ExpiryDate = hasExpiry ? DateTime.Today.AddDays(random.Next(-15, 180)) : null,
                    Quantity = random.Next(1, 6),
                    TrackDailyCost = trackDailyCost,
                    Notes = null,
                    CreatedAt = DateTime.Now.AddDays(-purchaseDaysAgo).AddHours(random.Next(0, 24)).AddMinutes(random.Next(0, 60)),
                    UpdatedAt = DateTime.Now,
                });
            }
        }

        await _db.InsertAllAsync(items);
    }

    #endregion

    #region Data Management

    public async Task ClearAllDataAsync()
    {
        await EnsureInitializedAsync();
        await _db.DeleteAllAsync<Item>();
    }

    #endregion

    #region Database

    public async Task<int> GetDbVersionAsync()
    {
        await EnsureInitializedAsync();
        return await GetDbVersionInternalAsync();
    }

    public async Task ImportDatabaseAsync(string sourcePath)
    {
        await EnsureInitializedAsync();

        // Validate source file
        if (!File.Exists(sourcePath))
            throw new FileNotFoundException("数据库文件不存在");

        var header = new byte[16];
        using (var fs = File.OpenRead(sourcePath))
        {
            var bytesRead = await fs.ReadAsync(header, 0, 16);
            if (bytesRead < 16)
                throw new InvalidOperationException("所选文件不是有效的 SQLite 数据库");
        }

        var sqliteHeader = "SQLite format 3\0"u8;
        for (var i = 0; i < 16; i++)
            if (header[i] != sqliteHeader[i])
                throw new InvalidOperationException("所选文件不是有效的 SQLite 数据库");

        // Close current connection
        await _db.CloseAsync();

        // Backup current database
        var backupPath = _dbPath + ".bak";
        if (File.Exists(_dbPath))
            File.Move(_dbPath, backupPath, overwrite: true);

        try
        {
            // Copy imported file to database path
            File.Copy(sourcePath, _dbPath, overwrite: true);

            // Reset and reinitialize (creates missing tables, runs migrations)
            _initialized = false;
            await InitializeAsync();

            // Delete backup on success
            if (File.Exists(backupPath))
                File.Delete(backupPath);
        }
        catch
        {
            // Restore backup on failure
            if (File.Exists(backupPath))
                File.Move(backupPath, _dbPath, overwrite: true);
            throw;
        }
    }

    #endregion
}
