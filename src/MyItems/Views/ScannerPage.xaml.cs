using ZXing.Net.Maui;

namespace MyItems.Views;

public partial class ScannerPage : ContentPage
{
    private bool _hasScanned;

    public ScannerPage()
    {
        InitializeComponent();

        if (BarcodeScanning.IsSupported)
        {
            CameraView.Options = new BarcodeReaderOptions
            {
                Formats = BarcodeFormats.All,
                AutoRotate = true,
                Multiple = false,
            };
        }
        else
        {
            CameraView.IsVisible = false;
            UnsupportedPanel.IsVisible = true;
        }
    }

    protected override async void OnNavigatedTo(NavigatedToEventArgs args)
    {
        base.OnNavigatedTo(args);

        if (!BarcodeScanning.IsSupported) return;

        var status = await Permissions.RequestAsync<Permissions.Camera>();
        if (status != PermissionStatus.Granted)
        {
            await Shell.Current.DisplayAlertAsync("提示", "需要相机权限才能扫码", "确定");
            await GoBackAsync();
        }
    }

    private async void OnBarcodesDetected(object? sender, BarcodeDetectionEventArgs e)
    {
        if (_hasScanned) return;

        var result = e.Results?.FirstOrDefault();
        if (result?.Value is null) return;

        _hasScanned = true;

        MainThread.BeginInvokeOnMainThread(async () =>
        {
            var parameters = new Dictionary<string, object>
            {
                { "barcode", result.Value }
            };
            await Shell.Current.GoToAsync("..", parameters);
        });
    }

    private async void OnCloseClicked(object? sender, EventArgs e)
    {
        await GoBackAsync();
    }

    private void OnTorchClicked(object? sender, EventArgs e)
    {
        if (!BarcodeScanning.IsSupported) return;
        CameraView.IsTorchOn = !CameraView.IsTorchOn;
    }

    private async Task GoBackAsync()
    {
        await Shell.Current.GoToAsync("..");
    }
}
