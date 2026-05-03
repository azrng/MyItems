namespace MyItems;

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
        ApplyTheme(RequestedTheme);
        RequestedThemeChanged += (_, e) => ApplyTheme(e.RequestedTheme);
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        return new Window(new AppShell());
    }

    private void ApplyTheme(AppTheme theme)
    {
        var dark = theme == AppTheme.Dark;

        SetColor("AppTextColor", dark ? "#E2E8F0" : "#0F172A");
        SetColor("AppTextSecondaryColor", dark ? "#94A3B8" : "#475569");
        SetColor("AppTextMutedColor", dark ? "#64748B" : "#64748B");
        SetColor("AppTextDisabledColor", dark ? "#475569" : "#94A3B8");
        SetColor("AppTextInverseColor", dark ? "#0F172A" : "White");

        SetColor("AppBackgroundColor", dark ? "#0F172A" : "#F8FAFC");
        SetColor("AppCardBackgroundColor", dark ? "#1E293B" : "White");
        SetColor("AppSurfaceColor", dark ? "#334155" : "#F1F5F9");
        SetColor("AppActiveBackgroundColor", dark ? "#1E3A5F" : "#D9EEFF");

        SetColor("AppBorderColor", dark ? "#334155" : "#E2E8F0");
        SetColor("AppBorderStrongColor", dark ? "#475569" : "#CBD5E1");

        SetColor("AppPrimaryContainerColor", dark ? "#1E3A5F" : "#D9EEFF");
        SetColor("AppSecondaryContainerColor", dark ? "#1A3D2E" : "#D9F6EE");

        SetColor("AppSuccessBgColor", dark ? "#1A3D2E" : "#DCFBE6");
        SetColor("AppWarningBgColor", dark ? "#3D2E0A" : "#FEEFC8");
        SetColor("AppErrorBgColor", dark ? "#3D0A10" : "#FFE0E4");

        SetColor("AppExpiredBgColor", dark ? "#3D0A10" : "#FFE0E4");
        SetColor("AppExpiringBgColor", dark ? "#3D2E0A" : "#FEEFC8");
        SetColor("AppSafeBgColor", dark ? "#1A3D2E" : "#DCFBE6");
        SetColor("AppNoExpiryBgColor", dark ? "#1E3A5F" : "#D9EEFF");
    }

    private void SetColor(string key, string hex)
    {
        if (Resources.ContainsKey(key))
            Resources[key] = Color.FromArgb(hex);
    }
}
