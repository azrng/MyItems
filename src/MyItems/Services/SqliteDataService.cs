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
            await _db.CreateTableAsync<Batch>();

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

    public async Task<Guid> SaveItemAsync(Item item)
    {
        await EnsureInitializedAsync();
        var existing = await _db.Table<Item>().Where(i => i.Id == item.Id).FirstOrDefaultAsync();
        if (existing is not null)
        {
            await _db.UpdateAsync(item);
        }
        else
        {
            await _db.InsertAsync(item);
        }
        return item.Id;
    }

    public async Task<int> ArchiveItemAsync(Guid itemId)
    {
        await EnsureInitializedAsync();
        var item = await _db.Table<Item>().Where(i => i.Id == itemId && !i.IsArchived).FirstOrDefaultAsync();
        if (item is null)
            return 0;

        item.IsArchived = true;
        item.UpdatedAt = DateTime.Now;
        return await _db.UpdateAsync(item);
    }

    #endregion

    #region Batch

    public async Task<List<Batch>> GetBatchesAsync()
    {
        var activeItemIds = (await GetItemsAsync()).Select(i => i.Id).ToHashSet();
        var allBatches = await _db.Table<Batch>().ToListAsync();
        return allBatches.Where(b => activeItemIds.Contains(b.ItemId)).ToList();
    }

    public async Task<int> SaveBatchAsync(Batch batch)
    {
        await EnsureInitializedAsync();
        var existing = await _db.Table<Batch>().Where(b => b.Id == batch.Id).FirstOrDefaultAsync();
        if (existing is not null)
            return await _db.UpdateAsync(batch);
        return await _db.InsertAsync(batch);
    }

    public async Task<int> DeleteBatchAsync(Guid batchId)
    {
        await EnsureInitializedAsync();
        var batch = await _db.Table<Batch>().Where(b => b.Id == batchId).FirstOrDefaultAsync();
        if (batch is null)
            return 0;

        return await _db.DeleteAsync(batch);
    }

    #endregion

    #region DTO Queries

    public async Task<List<BatchDisplayDto>> GetBatchDisplayDtosAsync()
    {
        var items = await GetItemsAsync();
        var itemLookup = items.ToDictionary(i => i.Id);
        var categories = await GetCategoriesAsync();
        var catLookup = categories.ToDictionary(c => c.Id);
        var batches = await GetBatchesAsync();

        return batches.Select(b =>
        {
            if (!itemLookup.TryGetValue(b.ItemId, out var item))
                return null;

            catLookup.TryGetValue(item.CategoryId, out var category);
            var expiryStatus = StatusHelper.CalculateExpiryStatus(b.ExpiryDate);

            return new BatchDisplayDto
            {
                BatchId = b.Id,
                ItemId = item.Id,
                ItemName = item.Name,
                ItemIcon = item.Icon,
                Brand = item.Brand,
                CategoryName = category?.Name ?? string.Empty,
                CategoryIcon = category?.Icon,
                PurchaseDate = b.PurchaseDate,
                PurchasePrice = b.PurchasePrice,
                ExpiryDate = b.ExpiryDate,
                Location = b.Location,
                Quantity = b.Quantity,
                Notes = b.Notes,
                BatchLabel = b.BatchLabel,
                TrackDailyCost = b.TrackDailyCost,
                ExpiryStatus = expiryStatus,
                ExpiryStatusText = StatusHelper.GetExpiryStatusText(expiryStatus, b.ExpiryDate),
                HoldingDays = StatusHelper.GetHoldingDays(b.PurchaseDate),
                DailyCost = StatusHelper.CalculateDailyCost(b.PurchasePrice, b.Quantity, b.PurchaseDate),
                DailyCostText = b.TrackDailyCost ? StatusHelper.GetDailyCostText(b.PurchasePrice, b.Quantity, b.PurchaseDate) : string.Empty,
                HoldingText = StatusHelper.GetHoldingText(b.PurchaseDate),
            };
        }).Where(d => d is not null).ToList()!;
    }

    public async Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync()
    {
        var batches = await GetBatchDisplayDtosAsync();

        return Enum.GetValues<ExpiryStatus>()
            .Select(status =>
            {
                var groupBatches = batches
                    .Where(b => b.ExpiryStatus == status)
                    .OrderBy(b => b.ExpiryDate)
                    .ToList();

                return new ExpiryGroupDto
                {
                    Status = status,
                    Title = StatusHelper.GetGroupTitle(status),
                    StatusIcon = StatusHelper.GetGroupIcon(status),
                    Batches = groupBatches,
                    IsExpanded = status is ExpiryStatus.Expired or ExpiryStatus.Expiring,
                };
            })
            .Where(g => g.Batches.Count > 0)
            .ToList();
    }

    public async Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync()
    {
        var items = await GetItemsAsync();
        var categories = await GetCategoriesAsync();
        var catLookup = categories.ToDictionary(c => c.Id);
        var batches = await GetBatchesAsync();
        var batchesByItem = batches.GroupBy(b => b.ItemId).ToDictionary(g => g.Key, g => g.ToList());

        return items.Select(item =>
        {
            catLookup.TryGetValue(item.CategoryId, out var category);
            batchesByItem.TryGetValue(item.Id, out var itemBatches);
            itemBatches ??= [];

            var worstStatus = itemBatches
                .Select(b => StatusHelper.CalculateExpiryStatus(b.ExpiryDate))
                .DefaultIfEmpty(ExpiryStatus.NoExpiry)
                .Min();

            var dailyCost = itemBatches.Sum(b => StatusHelper.CalculateDailyCost(b.PurchasePrice, b.Quantity, b.PurchaseDate));

            return new ItemDisplayDto
            {
                ItemId = item.Id,
                Name = item.Name,
                Icon = item.Icon,
                CategoryId = item.CategoryId,
                CategoryName = category?.Name ?? string.Empty,
                CategoryIcon = category?.Icon,
                Barcode = item.Barcode,
                Brand = item.Brand,
                DefaultLocation = item.DefaultLocation,
                BatchCount = itemBatches.Count,
                TotalSpent = itemBatches.Sum(b => b.PurchasePrice ?? 0),
                WorstExpiryStatus = worstStatus,
                WorstExpiryStatusText = StatusHelper.GetExpiryStatusText(worstStatus, null),
                DailyCostText = dailyCost > 0 ? $"{dailyCost:F2}/天" : null,
            };
        }).ToList();
    }

    public async Task<List<CategoryDto>> GetCategoryDtosAsync()
    {
        var categories = await GetCategoriesAsync();
        var items = await GetItemsAsync();
        var itemCounts = items.GroupBy(i => i.CategoryId).ToDictionary(g => g.Key, g => g.Count());

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

    public async Task<(decimal TotalSpent, int TotalBatches, int ValidBatches)> GetStatisticsAsync()
    {
        var items = await GetItemsAsync();
        var itemIdSet = items.Select(i => i.Id).ToHashSet();
        var batches = await GetBatchesAsync();
        var totalBatches = batches.Count;

        var allDisplay = await GetBatchDisplayDtosAsync();
        var validBatches = allDisplay
            .Where(b => itemIdSet.Contains(b.ItemId) && b.ExpiryStatus != ExpiryStatus.Expired)
            .ToList();

        var totalSpent = validBatches.Sum(b => b.PurchasePrice * b.Quantity ?? 0);
        return (totalSpent, totalBatches, validBatches.Count);
    }

    #endregion

    #region Excel Export

    public async Task<string> ExportToExcelAsync()
    {
        var batches = await GetBatchDisplayDtosAsync();
        var filePath = Path.Combine(FileSystem.CacheDirectory, $"MyItems_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx");

        using var workbook = new XLWorkbook();
        var ws = workbook.Worksheets.Add("物品清单");

        // Headers
        ws.Cell(1, 1).Value = "物品名称";
        ws.Cell(1, 2).Value = "品牌";
        ws.Cell(1, 3).Value = "分类";
        ws.Cell(1, 4).Value = "批次标签";
        ws.Cell(1, 5).Value = "购买日期";
        ws.Cell(1, 6).Value = "购入价格";
        ws.Cell(1, 7).Value = "保质期";
        ws.Cell(1, 8).Value = "状态";
        ws.Cell(1, 9).Value = "存放位置";
        ws.Cell(1, 10).Value = "数量";
        ws.Cell(1, 11).Value = "日均成本";

        // Data rows
        for (var i = 0; i < batches.Count; i++)
        {
            var b = batches[i];
            ws.Cell(i + 2, 1).Value = b.ItemName;
            ws.Cell(i + 2, 2).Value = b.Brand ?? string.Empty;
            ws.Cell(i + 2, 3).Value = b.CategoryName;
            ws.Cell(i + 2, 4).Value = b.BatchLabel;
            ws.Cell(i + 2, 5).Value = b.PurchaseDate?.ToString("yyyy-MM-dd") ?? string.Empty;
            ws.Cell(i + 2, 6).Value = (double)(b.PurchasePrice ?? 0);
            ws.Cell(i + 2, 7).Value = b.ExpiryDate?.ToString("yyyy-MM-dd") ?? "无";
            ws.Cell(i + 2, 8).Value = b.ExpiryStatusText;
            ws.Cell(i + 2, 9).Value = b.Location ?? string.Empty;
            ws.Cell(i + 2, 10).Value = b.Quantity;
            ws.Cell(i + 2, 11).Value = b.DailyCostText ?? string.Empty;
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
        var batches = new List<Batch>();

        foreach (var (catId, productNames, icon) in categoryData)
        {
            for (var i = 0; i < productNames.Length; i++)
            {
                var (name, brand) = productNames[i];
                var itemId = Guid.NewGuid();

                items.Add(new Item
                {
                    Id = itemId,
                    Name = name,
                    CategoryId = catId,
                    Brand = brand,
                    Icon = icon,
                    DefaultLocation = locations[random.Next(locations.Length)],
                    CreatedAt = DateTime.Now,
                    UpdatedAt = DateTime.Now,
                });

                // Each item gets 1-3 batches with varied dates
                var batchCount = random.Next(1, 4);
                for (var j = 0; j < batchCount; j++)
                {
                    var purchaseDaysAgo = random.Next(0, 90);
                    var hasExpiry = random.Next(100) < 70;
                    var trackDailyCost = random.Next(100) < 60;
                    var price = random.Next(3, 500) + random.Next(10, 99) / 100m;

                    batches.Add(new Batch
                    {
                        Id = Guid.NewGuid(),
                        ItemId = itemId,
                        PurchaseDate = DateTime.Today.AddDays(-purchaseDaysAgo),
                        PurchasePrice = price,
                        ExpiryDate = hasExpiry ? DateTime.Today.AddDays(random.Next(-15, 180)) : null,
                        Location = locations[random.Next(locations.Length)],
                        Quantity = random.Next(1, 6),
                        TrackDailyCost = trackDailyCost,
                        BatchLabel = DateTime.Today.AddDays(-purchaseDaysAgo).ToString("yyyyMMddHHmmss"),
                        CreatedAt = DateTime.Now,
                    });
                }
            }
        }

        await _db.InsertAllAsync(items);
        await _db.InsertAllAsync(batches);
    }

    #endregion

    #region Data Management

    public async Task ClearAllDataAsync()
    {
        await EnsureInitializedAsync();
        await _db.DeleteAllAsync<Item>();
        await _db.DeleteAllAsync<Batch>();
    }

    #endregion
}
