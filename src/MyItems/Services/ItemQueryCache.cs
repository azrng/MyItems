namespace MyItems.Services;

public sealed class ItemQueryCache : IItemQueryCache
{
    private readonly IDataService _dataService;
    private readonly SemaphoreSlim _loadLock = new(1, 1);
    private ItemQuerySnapshot? _snapshot;

    public ItemQueryCache(IDataService dataService)
    {
        _dataService = dataService;
    }

    public async Task<ItemQuerySnapshot> GetSnapshotAsync(bool forceRefresh = false)
    {
        if (!forceRefresh && _snapshot is not null)
            return _snapshot;

        await _loadLock.WaitAsync();
        try
        {
            if (!forceRefresh && _snapshot is not null)
                return _snapshot;

            var result = await _dataService.GetItemsWithStatisticsAsync();
            _snapshot = new ItemQuerySnapshot(
                result.Items,
                result.TotalSpent,
                result.TotalItems,
                result.ValidItems);

            return _snapshot;
        }
        finally
        {
            _loadLock.Release();
        }
    }

    public void Invalidate()
    {
        _snapshot = null;
    }
}
