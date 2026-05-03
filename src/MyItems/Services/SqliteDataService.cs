using ClosedXML.Excel;
using MyItems.Enums;
using MyItems.Helpers;
using MyItems.Models;
using MyItems.Models.DTOs;
using SQLite;

namespace MyItems.Services;

public class SqliteDataService : IDataService
{
    private readonly SQLiteAsyncConnection _db;
    private readonly SemaphoreSlim _initLock = new(1, 1);
    private bool _initialized;

    public SqliteDataService(string dbPath)
    {
        _db = new SQLiteAsyncConnection(dbPath);
    }

    public async Task InitializeAsync()
    {
        if (_initialized) return;
        await _initLock.WaitAsync();
        try
        {
            if (_initialized) return;

            await _db.CreateTableAsync<Category>();
            await _db.CreateTableAsync<Item>();

            var count = await _db.Table<Category>().CountAsync();
            if (count == 0)
            {
                var presets = MockDataService.GetPresetCategories();
                await _db.InsertAllAsync(presets);
            }

            _initialized = true;
        }
        finally
        {
            _initLock.Release();
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
            CategoryId = item.CategoryId,
            CategoryName = category?.Name ?? string.Empty,
            CategoryIcon = category?.Icon,
            PurchaseDate = item.PurchaseDate,
            PurchasePrice = item.PurchasePrice,
            ExpiryDate = item.ExpiryDate,
            Location = item.DefaultLocation,
            Quantity = item.Quantity,
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
        var itemCounts = await GetCategoryItemCountsAsync();

        return categories.Select(c => new CategoryDto
        {
            Id = c.Id,
            Name = c.Name,
            Icon = c.Icon,
            SortOrder = c.SortOrder,
            IsPreset = c.IsPreset,
            IsActive = c.IsActive,
            ItemCount = itemCounts.GetValueOrDefault(c.Id),
        }).ToList();
    }

    private async Task<Dictionary<Guid, int>> GetCategoryItemCountsAsync()
    {
        var rows = await _db.QueryAsync<CategoryItemCount>(
            "SELECT CategoryId, COUNT(*) AS Count FROM Items WHERE IsArchived = 0 GROUP BY CategoryId");

        return rows.ToDictionary(r => r.CategoryId, r => r.Count);
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

    #region Excel Export

    public async Task<string> ExportToExcelAsync()
    {
        await EnsureInitializedAsync();
        var items = await _db.Table<Item>().Where(i => !i.IsArchived).ToListAsync();
        var categories = await _db.Table<Category>().ToListAsync();
        var catLookup = categories.ToDictionary(c => c.Id);

        var filePath = Path.Combine(FileSystem.CacheDirectory, $"MyItems_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx");

        using var workbook = new XLWorkbook();
        var ws = workbook.Worksheets.Add("物品清单");

        ws.Cell(1, 1).Value = "物品名字";
        ws.Cell(1, 2).Value = "品牌";
        ws.Cell(1, 3).Value = "分类";
        ws.Cell(1, 4).Value = "购买日期";
        ws.Cell(1, 5).Value = "购买价格";
        ws.Cell(1, 6).Value = "创建时间";
        ws.Cell(1, 7).Value = "保质期";
        ws.Cell(1, 8).Value = "是否显示日均成本";
        ws.Cell(1, 9).Value = "备注";

        for (var i = 0; i < items.Count; i++)
        {
            var item = items[i];
            catLookup.TryGetValue(item.CategoryId, out var cat);
            var row = i + 2;

            ws.Cell(row, 1).Value = item.Name;
            ws.Cell(row, 2).Value = item.Brand ?? string.Empty;
            ws.Cell(row, 3).Value = cat?.Name ?? string.Empty;
            ws.Cell(row, 4).Value = item.PurchaseDate?.ToString("yyyy-MM-dd") ?? string.Empty;
            ws.Cell(row, 5).Value = item.PurchasePrice != null ? (double)item.PurchasePrice.Value : 0;
            ws.Cell(row, 6).Value = item.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss");
            ws.Cell(row, 7).Value = item.ExpiryDate?.ToString("yyyy-MM-dd") ?? "无";
            ws.Cell(row, 8).Value = item.TrackDailyCost ? "是" : "否";
            ws.Cell(row, 9).Value = item.Notes ?? string.Empty;
        }

        ws.Columns().AdjustToContents();
        workbook.SaveAs(filePath);
        return filePath;
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
}

public class CategoryItemCount
{
    public Guid CategoryId { get; set; }

    public int Count { get; set; }
}
