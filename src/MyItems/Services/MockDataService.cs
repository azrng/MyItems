using MyItems.Enums;
using MyItems.Helpers;
using MyItems.Models;
using MyItems.Models.DTOs;

namespace MyItems.Services;

public static class MockDataService
{
    private static readonly List<Category> PresetCategories = CreatePresetCategories();
    private static readonly List<Item> Items = CreateMockItems();
    private static readonly List<Batch> Batches = CreateMockBatches();

    #region Preset Categories

    public static List<Category> GetPresetCategories() => PresetCategories.ToList();

    private static List<Category> CreatePresetCategories() =>
    [
        new() { Id = Guid.Parse("10000000-0000-0000-0000-000000000001"), Name = "食品/饮料", Icon = "\U0001F354", SortOrder = 1, IsPreset = true },
        new() { Id = Guid.Parse("10000000-0000-0000-0000-000000000002"), Name = "化妆品/护肤品", Icon = "\U0001F484", SortOrder = 2, IsPreset = true },
        new() { Id = Guid.Parse("10000000-0000-0000-0000-000000000003"), Name = "药品/保健品", Icon = "\U0001F48A", SortOrder = 3, IsPreset = true },
        new() { Id = Guid.Parse("10000000-0000-0000-0000-000000000004"), Name = "日用品", Icon = "\U0001F9F4", SortOrder = 4, IsPreset = true },
        new() { Id = Guid.Parse("10000000-0000-0000-0000-000000000005"), Name = "电子产品", Icon = "\U0001F4BB", SortOrder = 5, IsPreset = true },
        new() { Id = Guid.Parse("10000000-0000-0000-0000-000000000006"), Name = "其他", Icon = "\U0001F4E6", SortOrder = 6, IsPreset = true },
    ];

    #endregion

    #region Mock Items + Batches

    public static List<Item> GetMockItems() => Items.Where(i => !i.IsArchived).ToList();

    private static List<Item> CreateMockItems() =>
    [
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000001"), Name = "纯牛奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000001"), Icon = "\U0001F95B", Brand = "蒙牛", DefaultLocation = "冰箱上层" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000002"), Name = "酸奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000001"), Icon = "\U0001F95B", Brand = "伊利", DefaultLocation = "冰箱上层" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000003"), Name = "感冒药", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000003"), Icon = "\U0001F48A", Brand = "三九", DefaultLocation = "药箱" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000004"), Name = "洗面奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000002"), Icon = "\U0001F9FC", Brand = "芙丽芳丝", DefaultLocation = "卫生间" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000005"), Name = "显示器", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000005"), Icon = "\U0001F5A5", Brand = "戴尔", DefaultLocation = "书桌" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000006"), Name = "电池", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000004"), Icon = "\U0001F50B", Brand = "南孚", DefaultLocation = "抽屉" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000007"), Name = "面霜", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000002"), Icon = "\U0001F9F4", Brand = "科颜氏", DefaultLocation = "卫生间" },
    ];

    public static List<Batch> GetMockBatches()
    {
        var activeItemIds = GetMockItems().Select(i => i.Id).ToHashSet();
        return Batches.Where(b => activeItemIds.Contains(b.ItemId)).ToList();
    }

    private static List<Batch> CreateMockBatches() =>
    [
        // 已过期
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000001"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000001"), PurchaseDate = DateTime.Today.AddMonths(-2), PurchasePrice = 15.5m, ExpiryDate = DateTime.Today.AddDays(-3), Location = "冰箱上层", Quantity = 2, BatchLabel = DateTime.Now.AddMonths(-2).ToString("yyyy-MM-dd HH:mm") },
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000002"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000003"), PurchaseDate = DateTime.Today.AddMonths(-6), PurchasePrice = 28.0m, ExpiryDate = DateTime.Today.AddDays(-15), Location = "药箱", Quantity = 1, BatchLabel = DateTime.Now.AddMonths(-6).ToString("yyyy-MM-dd HH:mm") },

        // 临期
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000003"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000002"), PurchaseDate = DateTime.Today.AddDays(-10), PurchasePrice = 8.9m, ExpiryDate = DateTime.Today.AddDays(2), Location = "冰箱上层", Quantity = 1, BatchLabel = DateTime.Now.AddDays(-10).ToString("yyyy-MM-dd HH:mm") },

        // 安全
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000004"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000004"), PurchaseDate = DateTime.Today.AddDays(-5), PurchasePrice = 89.0m, ExpiryDate = DateTime.Today.AddMonths(6), Location = "卫生间", Quantity = 1, BatchLabel = DateTime.Now.AddDays(-5).ToString("yyyy-MM-dd HH:mm") },
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000005"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000006"), PurchaseDate = DateTime.Today.AddMonths(-1), PurchasePrice = 12.0m, ExpiryDate = DateTime.Today.AddYears(3), Location = "抽屉", Quantity = 4, BatchLabel = DateTime.Now.AddMonths(-1).ToString("yyyy-MM-dd HH:mm") },
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000006"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000007"), PurchaseDate = DateTime.Today.AddDays(-3), PurchasePrice = 199.0m, ExpiryDate = DateTime.Today.AddMonths(12), Location = "卫生间", Quantity = 1, BatchLabel = DateTime.Now.AddDays(-3).ToString("yyyy-MM-dd HH:mm") },
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000007"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000001"), PurchaseDate = DateTime.Today.AddDays(-1), PurchasePrice = 16.0m, ExpiryDate = DateTime.Today.AddDays(30), Location = "冰箱上层", Quantity = 1, BatchLabel = DateTime.Now.AddDays(-1).ToString("yyyy-MM-dd HH:mm") },

        // 无保质期
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000008"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000005"), PurchaseDate = DateTime.Today.AddMonths(-2), PurchasePrice = 2999.0m, Location = "书桌", Quantity = 1, TrackDailyCost = false, BatchLabel = DateTime.Now.AddMonths(-2).ToString("yyyy-MM-dd HH:mm") },
    ];

    #endregion

    #region Mutations

    public static Guid AddItem(AddItemDto dto)
    {
        var category = PresetCategories.FirstOrDefault(c => c.Id == dto.CategoryId);
        var item = new Item
        {
            Id = Guid.NewGuid(),
            Name = dto.Name.Trim(),
            CategoryId = dto.CategoryId,
            Barcode = dto.Barcode,
            Brand = dto.Brand,
            Icon = category?.Icon ?? "\U0001F4E6",
            DefaultLocation = dto.DefaultLocation,
            CreatedAt = DateTime.Now,
            UpdatedAt = DateTime.Now,
        };

        Items.Add(item);
        Batches.Add(new Batch
        {
            Id = Guid.NewGuid(),
            ItemId = item.Id,
            PurchaseDate = dto.PurchaseDate,
            PurchasePrice = dto.PurchasePrice,
            ExpiryDate = dto.NoExpiry ? null : dto.ExpiryDate,
            Location = dto.Location,
            Quantity = Math.Max(1, dto.Quantity),
            TrackDailyCost = dto.TrackDailyCost,
            Notes = dto.Notes,
            BatchLabel = DateTime.Now.ToString("yyyy-MM-dd HH:mm"),
            CreatedAt = DateTime.Now,
        });

        return item.Id;
    }

    public static bool MarkBatchConsumed(Guid batchId) => RemoveBatch(batchId);

    public static bool RemoveBatch(Guid batchId)
    {
        var batch = Batches.FirstOrDefault(b => b.Id == batchId);
        if (batch is null)
            return false;

        return Batches.Remove(batch);
    }

    public static bool ArchiveItem(Guid itemId)
    {
        var item = Items.FirstOrDefault(i => i.Id == itemId && !i.IsArchived);
        if (item is null)
            return false;

        item.IsArchived = true;
        item.UpdatedAt = DateTime.Now;
        return true;
    }

    #endregion

    #region Composed DTOs

    public static List<BatchDisplayDto> GetBatchDisplayDtos()
    {
        var items = GetMockItems();
        var itemLookup = items.ToDictionary(i => i.Id);
        var categories = GetPresetCategories();
        var catLookup = categories.ToDictionary(c => c.Id);
        var batches = GetMockBatches();

        return batches.Select(b =>
        {
            var item = itemLookup[b.ItemId];
            var category = catLookup[item.CategoryId];
            var expiryStatus = StatusHelper.CalculateExpiryStatus(b.ExpiryDate);

            return new BatchDisplayDto
            {
                BatchId = b.Id,
                ItemId = item.Id,
                ItemName = item.Name,
                ItemIcon = item.Icon,
                Brand = item.Brand,
                CategoryName = category.Name,
                CategoryIcon = category.Icon,
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
        }).ToList();
    }

    public static List<ExpiryGroupDto> GetExpiryGroups()
    {
        var batches = GetBatchDisplayDtos();

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

    public static List<ItemDisplayDto> GetItemDisplayDtos()
    {
        var items = GetMockItems();
        var categories = GetPresetCategories();
        var catLookup = categories.ToDictionary(c => c.Id);
        var batches = GetMockBatches();
        var batchesByItem = batches.GroupBy(b => b.ItemId).ToDictionary(g => g.Key, g => g.ToList());

        return items.Select(item =>
        {
            var category = catLookup[item.CategoryId];
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
                CategoryName = category.Name,
                CategoryIcon = category.Icon,
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

    public static List<CategoryDto> GetCategoryDtos()
    {
        var categories = GetPresetCategories();
        var items = GetMockItems();
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

    #endregion

    #region Statistics

    public static (decimal TotalSpent, int TotalBatches, int ValidBatches) GetStatistics()
    {
        var items = GetMockItems();
        var itemIdSet = items.Select(i => i.Id).ToHashSet();
        var batches = GetMockBatches();
        var totalBatches = batches.Count;

        var allDisplay = GetBatchDisplayDtos();
        var validBatches = allDisplay
            .Where(b => itemIdSet.Contains(b.ItemId) && b.ExpiryStatus != Enums.ExpiryStatus.Expired)
            .ToList();

        var totalSpent = validBatches.Sum(b => b.PurchasePrice * b.Quantity ?? 0);
        return (totalSpent, totalBatches, validBatches.Count);
    }

    #endregion
}
