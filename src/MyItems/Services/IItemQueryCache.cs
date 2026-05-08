using MyItems.Models.DTOs;

namespace MyItems.Services;

public sealed record ItemQuerySnapshot(
    List<ItemDisplayDto> Items,
    decimal TotalSpent,
    int TotalItems,
    int ValidItems);

public interface IItemQueryCache
{
    Task<ItemQuerySnapshot> GetSnapshotAsync(bool forceRefresh = false);
    void Invalidate();
}
