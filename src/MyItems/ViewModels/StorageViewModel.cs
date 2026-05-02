using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class StorageViewModel : ObservableObject
{
    private readonly IDataService _dataService;

    [ObservableProperty]
    private bool isBusy;

    public StorageViewModel(IDataService dataService)
    {
        _dataService = dataService;
    }

    [RelayCommand]
    private async Task ExportExcelAsync()
    {
        IsBusy = true;
        try
        {
            var path = await _dataService.ExportToExcelAsync();
            await Share.Default.RequestAsync(new ShareFileRequest
            {
                Title = "导出物品数据",
                File = new ShareFile(path)
            });
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("导出失败", ex.Message, "确定");
        }
        IsBusy = false;
    }

    [RelayCommand]
    private async Task SeedTestDataAsync()
    {
        var confirm = await Shell.Current.DisplayAlertAsync("初始化测试数据", "将插入约 200 个测试物品，确认继续？", "确定", "取消");
        if (!confirm) return;

        IsBusy = true;
        await _dataService.SeedSampleDataAsync();
        IsBusy = false;
        await Shell.Current.DisplayAlertAsync("完成", "测试数据已初始化", "确定");
    }

    [RelayCommand]
    private async Task ClearAllDataAsync()
    {
        var confirm = await Shell.Current.DisplayAlertAsync("清空数据", "将删除所有物品和批次数据，此操作不可恢复！\n\n确定要继续吗？", "清空", "取消");
        if (!confirm) return;

        var secondConfirm = await Shell.Current.DisplayAlertAsync("二次确认", "真的要清空所有数据吗？", "确认清空", "再想想");
        if (!secondConfirm) return;

        IsBusy = true;
        await _dataService.ClearAllDataAsync();
        IsBusy = false;
        await Shell.Current.DisplayAlertAsync("完成", "所有数据已清空", "确定");
    }
}
