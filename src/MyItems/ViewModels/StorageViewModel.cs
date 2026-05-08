using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class StorageViewModel : ObservableObject
{
    private readonly IDataService _dataService;
    private readonly IItemQueryCache _itemQueryCache;

    [ObservableProperty]
    private bool isBusy;

    public StorageViewModel(IDataService dataService, IItemQueryCache itemQueryCache)
    {
        _dataService = dataService;
        _itemQueryCache = itemQueryCache;
    }

    [RelayCommand]
    private async Task ExportCsvAsync()
    {
        IsBusy = true;
        try
        {
            var path = await _dataService.ExportToCsvAsync();
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
    private async Task ImportCsvAsync()
    {
        var result = await FilePicker.Default.PickAsync(new PickOptions
        {
            PickerTitle = "选择CSV文件",
            FileTypes = new FilePickerFileType(
                new Dictionary<DevicePlatform, IEnumerable<string>>
                {
                    { DevicePlatform.Android, new[] { "text/csv", "application/csv" } },
                    { DevicePlatform.WinUI, new[] { ".csv" } },
                })
        });

        if (result is null) return;

        var confirm = await Shell.Current.DisplayAlertAsync("导入CSV",
            "将从CSV文件导入物品数据。\n\n注意：分类必须已存在才能导入成功。", "导入", "取消");
        if (!confirm) return;

        IsBusy = true;
        try
        {
            var (successCount, failureCount, errors) = await _dataService.ImportFromCsvAsync(result.FullPath);
            _itemQueryCache.Invalidate();

            var message = $"导入完成！\n成功：{successCount} 条\n失败：{failureCount} 条";

            if (errors.Count > 0)
            {
                message += "\n\n错误信息：\n" + string.Join("\n", errors.Take(10));
                if (errors.Count > 10)
                {
                    message += $"\n... 还有 {errors.Count - 10} 条错误";
                }
            }

            await Shell.Current.DisplayAlertAsync("导入结果", message, "确定");
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("导入失败", ex.Message, "确定");
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
        _itemQueryCache.Invalidate();
        IsBusy = false;
        await Shell.Current.DisplayAlertAsync("完成", "测试数据已初始化", "确定");
    }

    [RelayCommand]
    private async Task ClearAllDataAsync()
    {
        var confirm = await Shell.Current.DisplayAlertAsync("清空数据", "将删除所有物品数据，此操作不可恢复！\n\n确定要继续吗？", "清空", "取消");
        if (!confirm) return;

        var secondConfirm = await Shell.Current.DisplayAlertAsync("二次确认", "真的要清空所有数据吗？", "确认清空", "再想想");
        if (!secondConfirm) return;

        IsBusy = true;
        await _dataService.ClearAllDataAsync();
        _itemQueryCache.Invalidate();
        IsBusy = false;
        await Shell.Current.DisplayAlertAsync("完成", "所有数据已清空", "确定");
    }

    [RelayCommand]
    private async Task ImportDbAsync()
    {
        var result = await FilePicker.Default.PickAsync(new PickOptions
        {
            PickerTitle = "选择数据库文件",
            FileTypes = new FilePickerFileType(
                new Dictionary<DevicePlatform, IEnumerable<string>>
                {
                    { DevicePlatform.Android, new[] { "application/octet-stream" } },
                    { DevicePlatform.WinUI, new[] { ".db", ".sqlite", ".sqlite3" } },
                })
        });

        if (result is null) return;

        var confirm = await Shell.Current.DisplayAlertAsync("导入数据库",
            $"将用所选文件替换当前数据库，当前数据将被覆盖。\n\n确定要继续吗？", "导入", "取消");
        if (!confirm) return;

        IsBusy = true;
        try
        {
            await _dataService.ImportDatabaseAsync(result.FullPath);
            _itemQueryCache.Invalidate();
            await Shell.Current.DisplayAlertAsync("导入成功",
                "数据库已导入，请重启应用以加载新数据。", "确定");
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("导入失败", ex.Message, "确定");
        }
        IsBusy = false;
    }
}
