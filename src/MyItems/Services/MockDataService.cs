using MyItems.Enums;
using MyItems.Helpers;
using MyItems.Models;
using MyItems.Models.DTOs;

namespace MyItems.Services;

public static class MockDataService
{
    #region Preset Categories

    public static List<Category> GetPresetCategories() =>
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

    public static List<Item> GetMockItems() =>
    [
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000001"), Name = "纯牛奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000001"), Icon = "\U0001F95B", DefaultLocation = "冰箱上层" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000002"), Name = "酸奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000001"), Icon = "\U0001F95B", DefaultLocation = "冰箱上层" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000003"), Name = "感冒药", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000003"), Icon = "\U0001F48A", DefaultLocation = "药箱" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000004"), Name = "洗面奶", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000002"), Icon = "\U0001F9FC", DefaultLocation = "卫生间" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000005"), Name = "显示器", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000005"), Icon = "\U0001F5A5", DefaultLocation = "书桌" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000006"), Name = "电池", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000004"), Icon = "\U0001F50B", DefaultLocation = "抽屉" },
        new() { Id = Guid.Parse("20000000-0000-0000-0000-000000000007"), Name = "面霜", CategoryId = Guid.Parse("10000000-0000-0000-0000-000000000002"), Icon = "\U0001F9F4", DefaultLocation = "卫生间" },
    ];

    public static List<Batch> GetMockBatches() =>
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

        // 无保质期（保修期）
        new() { Id = Guid.Parse("30000000-0000-0000-0000-000000000008"), ItemId = Guid.Parse("20000000-0000-0000-0000-000000000005"), PurchaseDate = DateTime.Today.AddMonths(-2), PurchasePrice = 2999.0m, WarrantyDate = DateTime.Today.AddYears(2), Location = "书桌", Quantity = 1, BatchLabel = DateTime.Now.AddMonths(-2).ToString("yyyy-MM-dd HH:mm") },
    ];

    #endregion

    #region Composed DTOs

    public static List<BatchDisplayDto> GetBatchDisplayDtos()
    {
        var items = GetMockItems();
        var categories = GetPresetCategories();
        var batches = GetMockBatches();

        return batches.Select(b =>
        {
            var item = items.First(i => i.Id == b.ItemId);
            var category = categories.First(c => c.Id == item.CategoryId);
            var expiryStatus = StatusHelper.CalculateExpiryStatus(b.ExpiryDate);
            var warrantyStatus = StatusHelper.CalculateWarrantyStatus(b.WarrantyDate);

            return new BatchDisplayDto
            {
                BatchId = b.Id,
                ItemId = item.Id,
                ItemName = item.Name,
                ItemIcon = item.Icon,
                CategoryName = category.Name,
                CategoryIcon = category.Icon,
                PurchaseDate = b.PurchaseDate,
                PurchasePrice = b.PurchasePrice,
                ExpiryDate = b.ExpiryDate,
                WarrantyDate = b.WarrantyDate,
                Location = b.Location,
                Quantity = b.Quantity,
                Notes = b.Notes,
                BatchLabel = b.BatchLabel,
                ExpiryStatus = expiryStatus,
                WarrantyStatus = warrantyStatus,
                ExpiryStatusText = StatusHelper.GetExpiryStatusText(expiryStatus, b.ExpiryDate),
                WarrantyStatusText = StatusHelper.GetWarrantyStatusText(warrantyStatus, b.WarrantyDate),
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
        var batches = GetMockBatches();

        return items.Select(item =>
        {
            var category = categories.First(c => c.Id == item.CategoryId);
            var itemBatches = batches.Where(b => b.ItemId == item.Id).ToList();

            var worstStatus = itemBatches
                .Select(b => StatusHelper.CalculateExpiryStatus(b.ExpiryDate))
                .DefaultIfEmpty(ExpiryStatus.NoExpiry)
                .Min();

            var hasWarranty = itemBatches.Any(b => StatusHelper.CalculateWarrantyStatus(b.WarrantyDate) == WarrantyStatus.Active);

            return new ItemDisplayDto
            {
                ItemId = item.Id,
                Name = item.Name,
                Icon = item.Icon,
                CategoryId = item.CategoryId,
                CategoryName = category.Name,
                CategoryIcon = category.Icon,
                Barcode = item.Barcode,
                DefaultLocation = item.DefaultLocation,
                BatchCount = itemBatches.Count,
                TotalSpent = itemBatches.Sum(b => b.PurchasePrice ?? 0),
                WorstExpiryStatus = worstStatus,
                WorstExpiryStatusText = StatusHelper.GetExpiryStatusText(worstStatus, null),
                WarrantyStatusText = hasWarranty ? "保修中" : null,
            };
        }).ToList();
    }

    public static List<CategoryDto> GetCategoryDtos()
    {
        var categories = GetPresetCategories();
        var items = GetMockItems();

        return categories.Select(c => new CategoryDto
        {
            Id = c.Id,
            Name = c.Name,
            Icon = c.Icon,
            SortOrder = c.SortOrder,
            IsPreset = c.IsPreset,
            ItemCount = items.Count(i => i.CategoryId == c.Id),
        }).ToList();
    }

    #endregion
}
