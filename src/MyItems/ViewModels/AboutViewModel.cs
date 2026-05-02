using CommunityToolkit.Mvvm.ComponentModel;

namespace MyItems.ViewModels;

public partial class AboutViewModel : ObservableObject
{
    [ObservableProperty]
    private string appName = "我的物品";

    [ObservableProperty]
    private string version = "1.0.0";

    [ObservableProperty]
    private string author = "azrng";

    [ObservableProperty]
    private string description = "个人/家庭自用的物品管理 App，核心功能是跟踪物品的保质期，同时管理物品的购入、存放等信息。";

    [ObservableProperty]
    private string techStack = ".NET MAUI + SQLite";

    [ObservableProperty]
    private string projectUrl = "https://github.com/azrng/MyItems";
}
