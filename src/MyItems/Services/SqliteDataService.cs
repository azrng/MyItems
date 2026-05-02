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

    public SqliteDataService(string dbPath)
    {
        _db = new SQLiteAsyncConnection(dbPath);
    }

    public async Task InitializeAsync()
    {
        await _db.CreateTableAsync<Category>();
        await _db.CreateTableAsync<Item>();
        await _db.CreateTableAsync<Batch>();

        // Seed preset categories on first launch
        var count = await _db.Table<Category>().CountAsync();
        if (count == 0)
        {
            var presets = MockDataService.GetPresetCategories();
            await _db.InsertAllAsync(presets);
        }
    }

    #region Category

    public async Task<List<Category>> GetCategoriesAsync()
    {
        return await _db.Table<Category>().OrderBy(c => c.SortOrder).ToListAsync();
    }

    public async Task<int> SaveCategoryAsync(Category category)
    {
        var existing = await _db.Table<Category>().Where(c => c.Id == category.Id).FirstOrDefaultAsync();
        if (existing is not null)
            return await _db.UpdateAsync(category);

        return await _db.InsertAsync(category);
    }

    public async Task<int> DeleteCategoryAsync(Category category)
    {
        return await _db.DeleteAsync(category);
    }

    #endregion

    #region Item

    public async Task<List<Item>> GetItemsAsync()
    {
        return await _db.Table<Item>().Where(i => !i.IsArchived).ToListAsync();
    }

    public async Task<Guid> SaveItemAsync(Item item)
    {
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
        return await _db.InsertAsync(batch);
    }

    public async Task<int> DeleteBatchAsync(Guid batchId)
    {
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
}
