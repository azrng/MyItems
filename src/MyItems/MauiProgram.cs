using CommunityToolkit.Maui;
using MyItems.Services;
using MyItems.ViewModels;
using MyItems.Views;
using Syncfusion.Maui.Toolkit.Hosting;
using ZXing.Net.Maui.Controls;

namespace MyItems;

public static class MauiProgram
{
    public static string DatabasePath { get; private set; } = string.Empty;

    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit()
            .ConfigureSyncfusionToolkit()
            .UseBarcodeReader()
            .ConfigureFonts(fonts =>
            {
            });

#if ANDROID
        DatabasePath = GetAndroidDatabasePath();
#else
        DatabasePath = Path.Combine(FileSystem.AppDataDirectory, "myitems.db");
#endif

        // Register database service as singleton (lazy init on first use)
        builder.Services.AddSingleton<IDataService>(_ => new SqliteDataService(DatabasePath));

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
        builder.Services.AddTransient<ScannerPage>();

        return builder.Build();
    }

#if ANDROID
    private static string GetAndroidDatabasePath()
    {
        // Use app-specific external storage: /sdcard/Android/data/com.myitems.app/files/
        var dbDir = Platform.AppContext.GetExternalFilesDir(null)?.AbsolutePath;
        if (dbDir is null)
            return Path.Combine(FileSystem.AppDataDirectory, "myitems.db");

        if (!Directory.Exists(dbDir))
            Directory.CreateDirectory(dbDir);

        var newPath = Path.Combine(dbDir, "myitems.db");

        // Migrate from internal storage if needed
        var oldPath = Path.Combine(FileSystem.AppDataDirectory, "myitems.db");
        if (File.Exists(oldPath) && !File.Exists(newPath))
            File.Move(oldPath, newPath);

        return newPath;
    }
#endif
}
