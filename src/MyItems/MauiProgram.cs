using CommunityToolkit.Maui;
using MyItems.Services;
using MyItems.ViewModels;
using MyItems.Views;
using Syncfusion.Maui.Toolkit.Hosting;

namespace MyItems;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit()
            .ConfigureSyncfusionToolkit()
            .ConfigureFonts(fonts =>
            {
            });

        // Register database service as singleton (lazy init on first use)
        builder.Services.AddSingleton<IDataService>(_ =>
        {
            var dbPath = Path.Combine(FileSystem.AppDataDirectory, "myitems.db");
            return new SqliteDataService(dbPath);
        });

        // Register ViewModels
        builder.Services.AddTransient<MainViewModel>();
        builder.Services.AddTransient<ExpiringViewModel>();
        builder.Services.AddTransient<ItemLibraryViewModel>();
        builder.Services.AddTransient<AddItemViewModel>();
        builder.Services.AddTransient<ItemDetailViewModel>();
        builder.Services.AddTransient<CategoryViewModel>();
        builder.Services.AddTransient<AboutViewModel>();
        builder.Services.AddTransient<StorageViewModel>();

        // Register Pages
        builder.Services.AddTransient<MainPage>();
        builder.Services.AddTransient<ExpiringPage>();
        builder.Services.AddTransient<ItemLibraryPage>();
        builder.Services.AddTransient<AddItemPage>();
        builder.Services.AddTransient<ItemDetailPage>();
        builder.Services.AddTransient<CategoryPage>();
        builder.Services.AddTransient<AboutPage>();
        builder.Services.AddTransient<StoragePage>();

        return builder.Build();
    }
}
