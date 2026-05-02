using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ItemDetailViewModel : ObservableObject, IQueryAttributable
{
    public ObservableCollection<BatchDisplayDto> Batches { get; } = [];

    [ObservableProperty]
    private ItemDisplayDto? item;

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string itemName = string.Empty;

    [ObservableProperty]
    private string categoryName = string.Empty;

    [ObservableProperty]
    private string? itemLocation;

    [ObservableProperty]
    private string? barcode;

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.TryGetValue("itemId", out var idObj) && idObj is string idStr && Guid.TryParse(idStr, out var itemId))
        {
            LoadItem(itemId);
        }
    }

    [RelayCommand]
    private void Refresh()
    {
        if (Item is not null)
            LoadItem(Item.ItemId);
    }

    [RelayCommand]
    private async Task AddBatchAsync()
    {
        // Phase 2: navigate to add batch page
        await Shell.Current.DisplayAlertAsync("添加批次", "添加批次功能将在后续版本实现", "确定");
    }

    [RelayCommand]
    private async Task DeleteBatchAsync(BatchDisplayDto batch)
    {
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除批次「{batch.BatchLabel}」吗？", "删除", "取消");
        if (confirm)
        {
            Batches.Remove(batch);
        }
    }

    private void LoadItem(Guid itemId)
    {
        IsLoading = true;

        var items = MockDataService.GetItemDisplayDtos();
        var item = items.FirstOrDefault(i => i.ItemId == itemId);
        if (item is null)
        {
            IsLoading = false;
            return;
        }

        Item = item;
        ItemName = item.Name;
        CategoryName = item.CategoryName;
        ItemLocation = item.DefaultLocation;
        Barcode = item.Barcode;

        var allBatches = MockDataService.GetBatchDisplayDtos();
        var itemBatches = allBatches.Where(b => b.ItemId == itemId).ToList();

        Batches.Clear();
        foreach (var batch in itemBatches)
            Batches.Add(batch);

        IsLoading = false;
    }
}
