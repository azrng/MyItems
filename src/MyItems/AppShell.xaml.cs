using System.Windows.Input;
using MyItems.Views;
using MyItems.Services;

namespace MyItems;

public partial class AppShell : Shell
{
    private IItemQueryCache? _itemQueryCache;
    private IPreferencesService? _preferencesService;

    public ICommand AboutCommand { get; }
    public ICommand CategoryCommand { get; }

    public AppShell()
    {
        InitializeComponent();

        AboutCommand = new Command(async () =>
        {
            await GoToAsync(nameof(AboutPage));
        });

        CategoryCommand = new Command(async () =>
        {
            await GoToAsync("category");
        });

        Routing.RegisterRoute("add", typeof(AddItemPage));
        Routing.RegisterRoute("itemdetail", typeof(ItemDetailPage));
        Routing.RegisterRoute(nameof(AboutPage), typeof(AboutPage));
        Routing.RegisterRoute("category", typeof(CategoryPage));
        Routing.RegisterRoute("storage", typeof(StoragePage));
        Routing.RegisterRoute("scanner", typeof(ScannerPage));
        Routing.RegisterRoute("advancedsearch", typeof(AdvancedSearchPage));

        // 延迟初始化通知检查，避免构造函数中获取服务
        _ = InitializeNotificationBadgeAsync();
    }

    private async Task InitializeNotificationBadgeAsync()
    {
        try
        {
            // 延迟执行，确保服务容器已初始化
            await Task.Delay(100);

            // 安全获取服务
            _itemQueryCache = GetCurrentService<IItemQueryCache>();
            _preferencesService = GetCurrentService<IPreferencesService>();

            if (_itemQueryCache != null)
            {
                await CheckExpiryNotificationsAsync();
            }
        }
        catch (Exception ex)
        {
            // 静默处理错误，不影响启动
            System.Diagnostics.Debug.WriteLine($"通知初始化失败: {ex.Message}");
        }
    }

    private T? GetCurrentService<T>() where T : class
    {
        try
        {
            // 尝试从当前Handler获取
            var handler = Handler ?? App.Current?.Handler;
            if (handler?.MauiContext?.Services != null)
            {
                return handler.MauiContext.Services.GetService<T>();
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"获取服务 {typeof(T).Name} 失败: {ex.Message}");
        }
        return null;
    }

    private async Task CheckExpiryNotificationsAsync()
    {
        if (_itemQueryCache == null) return;

        try
        {
            var snapshot = await _itemQueryCache.GetSnapshotAsync();

            var threeDaysFromNow = DateTime.Now.AddDays(3);
            var hasExpiring = snapshot.Items
                .Where(item => item.ExpiryStatus != Enums.ExpiryStatus.Safe && item.ExpiryStatus != Enums.ExpiryStatus.NoExpiry)
                .Any(item => item.ExpiryDate.HasValue && item.ExpiryDate.Value <= threeDaysFromNow);

            // 确保在UI线程上更新UI
            Dispatcher.Dispatch(() =>
            {
                NotificationButton.IsVisible = hasExpiring;
                NotificationBadge.IsVisible = hasExpiring;
            });
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"检查通知失败: {ex.Message}");
        }
    }

    private async void OnNotificationClicked(object? sender, TappedEventArgs e)
    {
        try
        {
            // 标记为已读
            if (_preferencesService != null)
            {
                _preferencesService.SetExpiryNotificationShown(true);
            }

            // 更新UI
            NotificationButton.IsVisible = false;
            NotificationBadge.IsVisible = false;

            // 直接选中临期 Tab，避免 Shell 自动路由名不稳定导致跳转失败。
            if (CurrentItem is TabBar tabBar)
            {
                tabBar.CurrentItem = ExpiringTab;
            }
            else
            {
                await GoToAsync("//expiring/expiring-page");
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"打开临期页面失败: {ex.Message}");
            await DisplayAlertAsync("错误", "无法打开临期页面", "确定");
        }
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        // 页面出现时重新检查临期物品
        _ = CheckExpiryNotificationsSafeAsync();
    }

    private async Task CheckExpiryNotificationsSafeAsync()
    {
        try
        {
            if (_itemQueryCache != null)
            {
                await CheckExpiryNotificationsAsync();
            }
        }
        catch (Exception ex)
        {
            // 静默处理错误
            System.Diagnostics.Debug.WriteLine($"页面出现检查失败: {ex.Message}");
        }
    }
}
