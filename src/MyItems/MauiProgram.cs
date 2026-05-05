using CommunityToolkit.Maui;
using MyItems.Services;
using MyItems.ViewModels;
using MyItems.Views;
using UraniumUI;
using ZXing.Net.Maui.Controls;

namespace MyItems;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit()
            .UseUraniumUI()
            .UseUraniumUIMaterial()
            .UseBarcodeReader()
            .ConfigureFonts(fonts =>
            {
                // Material icons will be added later
            });

        // Register database service as singleton (lazy init on first use)
        builder.Services.AddSingleton<IDataService>(_ =>
        {
            var dbPath = Path.Combine(FileSystem.AppDataDirectory, "myitems.db");
            return new SqliteDataService(dbPath);
        });

        // Register preferences service
        builder.Services.AddSingleton<IPreferencesService, PreferencesService>();

        // Register ViewModels
        builder.Services.AddTransient<MainViewModel>();
        builder.Services.AddTransient<ExpiringViewModel>();
        builder.Services.AddTransient<ItemLibraryViewModel>();
        builder.Services.AddTransient<AddItemViewModel>();
        builder.Services.AddTransient<ItemDetailViewModel>();
        builder.Services.AddTransient<CategoryViewModel>();
        builder.Services.AddTransient<AboutViewModel>();
        builder.Services.AddTransient<StorageViewModel>();
        builder.Services.AddTransient<AdvancedSearchViewModel>();

        // Register Pages
        builder.Services.AddTransient<MainPage>();
        builder.Services.AddTransient<ExpiringPage>();
        builder.Services.AddTransient<ItemLibraryPage>();
        builder.Services.AddTransient<AddItemPage>();
        builder.Services.AddTransient<ItemDetailPage>();
        builder.Services.AddTransient<CategoryPage>();
        builder.Services.AddTransient<AboutPage>();
        builder.Services.AddTransient<StoragePage>();
        builder.Services.AddTransient<ScannerPage>();
        builder.Services.AddTransient<AdvancedSearchPage>();

        return builder.Build();
    }
}
