using System.Net.Http.Json;
using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Maui.ApplicationModel;

namespace MyItems.ViewModels;

public partial class AboutViewModel : ObservableObject
{
    private const string RepoUrl = "https://github.com/azrng/MyItems";
    private const string VersionsUrl = "https://github.com/azrng/MyItems/releases/latest/download/versions.json";
    private const string ThemePreferenceKey = "app_theme";

    [ObservableProperty]
    private partial string AppName { get; set; } = "我的物品";

    [ObservableProperty]
    private partial string Version { get; set; } = AppInfo.Current.VersionString;

    [ObservableProperty]
    private partial string Author { get; set; } = "azrng";

    [ObservableProperty]
    private partial string Description { get; set; } = "个人/家庭自用的物品管理 App，核心功能是跟踪物品的保质期，同时管理物品的购入、存放等信息。";

    [ObservableProperty]
    private partial string TechStack { get; set; } = ".NET MAUI + SQLite";

    [ObservableProperty]
    private partial string ProjectUrl { get; set; } = RepoUrl;

    [ObservableProperty]
    private partial int SelectedThemeIndex { get; set; }

    public List<string> ThemeOptions { get; } = new() { "跟随系统", "浅色模式", "深色模式" };

    public AboutViewModel()
    {
        LoadThemePreference();
    }

    private void LoadThemePreference()
    {
        var themePreference = Preferences.Get(ThemePreferenceKey, 0);
        SelectedThemeIndex = themePreference;
    }

    partial void OnSelectedThemeIndexChanged(int value)
    {
        Preferences.Set(ThemePreferenceKey, value);
        ApplyTheme(value);
    }

    private static void ApplyTheme(int themeIndex)
    {
        var theme = themeIndex switch
        {
            0 => AppTheme.Unspecified,
            1 => AppTheme.Light,
            2 => AppTheme.Dark,
            _ => AppTheme.Unspecified
        };

        Application.Current!.UserAppTheme = theme;

        if (Application.Current is App app)
        {
            app.ApplyTheme(theme == AppTheme.Unspecified
                ? Application.Current.RequestedTheme
                : theme);
        }
    }

    [ObservableProperty]
    private partial bool IsCheckingUpdate { get; set; }

    [ObservableProperty]
    private partial string UpdateStatusText { get; set; } = string.Empty;

    [RelayCommand]
    private async Task CheckUpdateAsync()
    {
        if (IsCheckingUpdate) return;

        IsCheckingUpdate = true;
        UpdateStatusText = "正在检查更新...";

        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
            var versions = await http.GetFromJsonAsync<List<VersionEntry>>(VersionsUrl);

            if (versions is { Count: > 0 })
            {
                var latest = versions[0];
                var current = AppInfo.Current.VersionString;

                if (IsNewerVersion(latest.Version, current))
                {
                    UpdateStatusText = $"发现新版本 v{latest.Version}";
                    var open = await Shell.Current.DisplayAlertAsync(
                        "发现新版本",
                        $"当前版本: v{current}\n最新版本: v{latest.Version}\n发布时间: {latest.PubTime:yyyy-MM-dd HH:mm}",
                        "前往下载",
                        "稍后再说");

                    if (open)
                        await Launcher.Default.OpenAsync($"{RepoUrl}/releases/latest");
                }
                else
                {
                    UpdateStatusText = "当前已是最新版本";
                }
            }
            else
            {
                UpdateStatusText = "无法获取版本信息";
            }
        }
        catch (Exception)
        {
            UpdateStatusText = "检查更新失败，请检查网络";
        }
        finally
        {
            IsCheckingUpdate = false;
        }
    }

    [RelayCommand]
    private async Task OpenProjectUrlAsync()
    {
        await Launcher.Default.OpenAsync(RepoUrl);
    }

    private static bool IsNewerVersion(string remote, string local)
    {
        if (System.Version.TryParse(remote.TrimStart('v'), out var r) &&
            System.Version.TryParse(local.TrimStart('v'), out var l))
        {
            return r > l;
        }
        return false;
    }

    private record VersionEntry(
        string PacketName,
        string Hash,
        string Version,
        string Url,
        DateTime PubTime);
}
