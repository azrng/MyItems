using MyItems.Enums;
using MyItems.Helpers;
using MyItems.Models;
using MyItems.Models.DTOs;

namespace MyItems.Services;

public static class MockDataService
{
    private static readonly List<Category> PresetCategories = CreatePresetCategories();
    private static readonly List<Item> Items = CreateMockItems();

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

    #region Mock Items

    public static List<Item> GetMockItems() => Items.Where(i => !i.IsArchived).ToList();

    private static List<Item> CreateMockItems() =>
    [
        // 已过期
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000001"), Name = "纯牛奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000001"), Icon = "\U0001F95B", Brand = "蒙牛", DefaultLocation = "冰箱上层", PurchaseDate = DateTime.Today.AddMonths(-2), PurchasePrice = 15.5m, ExpiryDate = DateTime.Today.AddDays(-3), Quantity = 2, CreatedAt = DateTime.Now.AddMonths(-2) },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000003"), Name = "感冒药", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000003"), Icon = "\U0001F48A", Brand = "三九", DefaultLocation = "药箱", PurchaseDate = DateTime.Today.AddMonths(-6), PurchasePrice = 28.0m, ExpiryDate = DateTime.Today.AddDays(-15), Quantity = 1, CreatedAt = DateTime.Now.AddMonths(-6) },

        // 临期
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000002"), Name = "酸奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000001"), Icon = "\U0001F95B", Brand = "伊利", DefaultLocation = "冰箱上层", PurchaseDate = DateTime.Today.AddDays(-10), PurchasePrice = 8.9m, ExpiryDate = DateTime.Today.AddDays(2), Quantity = 1, CreatedAt = DateTime.Now.AddDays(-10) },

        // 安全
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000004"), Name = "洗面奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000002"), Icon = "\U0001F9FC", Brand = "芙丽芳丝", DefaultLocation = "卫生间", PurchaseDate = DateTime.Today.AddDays(-5), PurchasePrice = 89.0m, ExpiryDate = DateTime.Today.AddMonths(6), Quantity = 1, CreatedAt = DateTime.Now.AddDays(-5) },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000006"), Name = "电池", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000004"), Icon = "\U0001F50B", Brand = "南孚", DefaultLocation = "抽屉", PurchaseDate = DateTime.Today.AddMonths(-1), PurchasePrice = 12.0m, ExpiryDate = DateTime.Today.AddYears(3), Quantity = 4, CreatedAt = DateTime.Now.AddMonths(-1) },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000007"), Name = "面霜", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000002"), Icon = "\U0001F9F4", Brand = "科颜氏", DefaultLocation = "卫生间", PurchaseDate = DateTime.Today.AddDays(-3), PurchasePrice = 199.0m, ExpiryDate = DateTime.Today.AddMonths(12), Quantity = 1, CreatedAt = DateTime.Now.AddDays(-3) },

        // 无保质期
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000005"), Name = "显示器", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000005"), Icon = "\U0001F5A5", Brand = "戴尔", DefaultLocation = "书桌", PurchaseDate = DateTime.Today.AddMonths(-2), PurchasePrice = 2999.0m, Quantity = 1, TrackDailyCost = false, CreatedAt = DateTime.Now.AddMonths(-2) },
    ];

    #endregion

    #region Mutations

    public static Guid AddItem(Item item)
    {
        Items.Add(item);
        return item.Id;
    }

    public static bool RemoveItem(Guid itemId)
    {
        var item = Items.FirstOrDefault(i => i.Id == itemId);
        if (item is null)
            return false;

        return Items.Remove(item);
    }

    #endregion

    #region Composed DTOs

    public static List<ItemDisplayDto> GetItemDisplayDtos()
    {
        var items = GetMockItems();
        var categories = GetPresetCategories();
        var catLookup = categories.ToDictionary(c => c.Id);

        return items.Select(item =>
        {
            var category = catLookup[item.CategoryId];
            var expiryStatus = StatusHelper.CalculateExpiryStatus(item.ExpiryDate);

            return new ItemDisplayDto
            {
                ItemId = item.Id,
                ItemName = item.Name,
                ItemIcon = item.Icon,
                Brand = item.Brand,
                CategoryId = item.CategoryId,
                CategoryName = category.Name,
                CategoryIcon = category.Icon,
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
        }).ToList();
    }

    public static List<ExpiryGroupDto> GetExpiryGroups()
    {
        var dtos = GetItemDisplayDtos();

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

    public static (decimal TotalSpent, int TotalItems, int ValidItems) GetStatistics()
    {
        var allDisplay = GetItemDisplayDtos();
        var totalItems = allDisplay.Count;
        var validItems = allDisplay.Where(d => d.ExpiryStatus != ExpiryStatus.Expired).ToList();
        var totalSpent = validItems.Sum(d => (d.PurchasePrice ?? 0) * d.Quantity);

        return (totalSpent, totalItems, validItems.Count);
    }

    #endregion
}
