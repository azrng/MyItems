using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.OS;
using Android.Provider;

namespace MyItems;

[Activity(
    Theme = "@style/Maui.SplashTheme",
    MainLauncher = true,
    ConfigurationChanges = ConfigChanges.ScreenSize
        | ConfigChanges.Orientation
        | ConfigChanges.UiMode
        | ConfigChanges.ScreenLayout
        | ConfigChanges.SmallestScreenSize
        | ConfigChanges.Density)]
public class MainActivity : MauiAppCompatActivity
{
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);
        SQLitePCL.Batteries_V2.Init();
        RequestStoragePermission();
    }

    private void RequestStoragePermission()
    {
        // Android 11+ needs MANAGE_EXTERNAL_STORAGE for public directory access
        if (Build.VERSION.SdkInt >= BuildVersionCodes.R)
        {
            if (!Android.OS.Environment.IsExternalStorageManager)
            {
                var intent = new Intent(Settings.ActionManageAppAllFilesAccessPermission);
                intent.SetData(Android.Net.Uri.Parse($"package:{PackageName}"));
                StartActivity(intent);
            }
        }
        else
        {
            if (CheckSelfPermission(Android.Manifest.Permission.WriteExternalStorage) != Permission.Granted)
                RequestPermissions(new[] { Android.Manifest.Permission.WriteExternalStorage }, 100);
        }
    }
}
