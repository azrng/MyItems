using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.Tests;

public sealed class FakeItemQueryCache : IItemQueryCache
{
    public Func<ItemQuerySnapshot>? LoadSnapshot { get; init; }
    public int LoadCount { get; private set; }
    public int InvalidateCount { get; private set; }

    public Task<ItemQuerySnapshot> GetSnapshotAsync(bool forceRefresh = false)
    {
        LoadCount++;
        if (LoadSnapshot is not null)
            return Task.FromResult(LoadSnapshot());

        return Task.FromResult(new ItemQuerySnapshot(new List<ItemDisplayDto>(), 0, 0, 0));
    }

    public void Invalidate()
    {
        InvalidateCount++;
    }
}
