using Microsoft.Maui.ApplicationModel;
using MyItems.Helpers;

namespace MyItems;

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
        LoadAndApplyTheme();
        RequestedThemeChanged += (_, e) =>
        {
            if (UserAppTheme == AppTheme.Unspecified)
                ApplyTheme(e.RequestedTheme);
        };
    }

    private void LoadAndApplyTheme()
    {
        var selectedTheme = ToAppTheme(ThemePreferenceHelper.ToPreference(
            Preferences.Get(ThemePreferenceHelper.PreferenceKey, 0)));

        UserAppTheme = selectedTheme;
        ApplyTheme(ResolveEffectiveTheme(selectedTheme));
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        return new Window(new AppShell());
    }

    public void ApplyTheme(AppTheme theme)
    {
        var dark = theme == AppTheme.Dark;

        SetColor("AppTextColor", dark ? "#E2E8F0" : "#0F172A");
        SetColor("AppTextSecondaryColor", dark ? "#94A3B8" : "#475569");
        SetColor("AppTextMutedColor", dark ? "#94A3B8" : "#64748B");
        SetColor("AppTextDisabledColor", dark ? "#94A3B8" : "#94A3B8");
        SetColor("AppTextInverseColor", dark ? "#0F172A" : "White");

        SetColor("AppBackgroundColor", dark ? "#0F172A" : "#F8FAFC");
        SetColor("AppCardBackgroundColor", dark ? "#1E293B" : "White");
        SetColor("AppSurfaceColor", dark ? "#334155" : "#F1F5F9");
        SetColor("AppActiveBackgroundColor", dark ? "#4A1F27" : "#FFE8E8");

        SetColor("AppBorderColor", dark ? "#334155" : "#E2E8F0");
        SetColor("AppBorderStrongColor", dark ? "#475569" : "#CBD5E1");

        SetColor("AppPrimaryContainerColor", dark ? "#1E3A5F" : "#D9EEFF");
        SetColor("AppSecondaryContainerColor", dark ? "#1A3D2E" : "#D9F6EE");

        SetColor("AppSuccessBgColor", dark ? "#1A3D2E" : "#DCFBE6");
        SetColor("AppSuccessColor", dark ? "#4EC89D" : "#22A97E");
        SetColor("AppSafeColor", dark ? "#4EC89D" : "#22A97E");
        SetColor("AppWarningColor", dark ? "#FFD98A" : "#B76A00");
        SetColor("AppWarningBgColor", dark ? "#3D2E0A" : "#FFF1B8");
        SetColor("AppErrorColor", dark ? "#FF8A9A" : "#D92D46");
        SetColor("AppErrorBgColor", dark ? "#3D0A10" : "#FFE4E8");

        SetColor("AppExpiredColor", dark ? "#FF8A9A" : "#D92D46");
        SetColor("AppExpiredBgColor", dark ? "#3D0A10" : "#FFE4E8");
        SetColor("AppExpiringColor", dark ? "#FFD98A" : "#B76A00");
        SetColor("AppExpiringBgColor", dark ? "#3D2E0A" : "#FFF1B8");
        SetColor("AppSafeBgColor", dark ? "#1A3D2E" : "#DCFBE6");
        SetColor("AppNoExpiryColor", dark ? "#74B8F2" : "#4D9DE0");
        SetColor("AppNoExpiryBgColor", dark ? "#1E3A5F" : "#D9EEFF");

        SetColor("ModernPrimary", dark ? "#FF8A9A" : "#FF6B6B");
        SetColor("ModernPrimaryDark", dark ? "#FF6E83" : "#FF5252");
        SetColor("ModernPrimaryLight", dark ? "#5A1F2A" : "#FFB3B3");
        SetColor("ModernSecondary", dark ? "#4EC89D" : "#4ECDC4");
        SetColor("ModernSecondaryDark", dark ? "#22A97E" : "#3DB8B0");
        SetColor("ModernSecondaryLight", dark ? "#173F35" : "#7EDDD6");
        SetColor("ModernAccent", dark ? "#F8B72B" : "#FFE66D");
        SetColor("ModernAccentDark", dark ? "#D99A00" : "#FFD93D");

        SetColor("ModernSurface", dark ? "#1E293B" : "#FFFFFF");
        SetColor("ModernSurfaceVariant", dark ? "#273449" : "#F8F9FA");
        SetColor("ModernSurfaceContainer", dark ? "#334155" : "#F1F3F5");
        SetColor("ModernBackground", dark ? "#0F172A" : "#FAFAFA");
        SetColor("ModernOnBackground", dark ? "#E2E8F0" : "#1A1A1A");

        SetColor("ModernError", dark ? "#FF8A9A" : "#D92D46");
        SetColor("ModernErrorContainer", dark ? "#4B111C" : "#FFE4E8");
        SetColor("ModernErrorText", dark ? "#FFB4C0" : "#B42318");
        SetColor("ModernSuccess", dark ? "#4EC89D" : "#22A97E");
        SetColor("ModernSuccessContainer", dark ? "#1A3D2E" : "#DCFBE6");
        SetColor("ModernSuccessText", dark ? "#A8F0D2" : "#146C52");
        SetColor("ModernWarning", dark ? "#F8B72B" : "#F5B51B");
        SetColor("ModernWarningContainer", dark ? "#4A3407" : "#FFF1B8");
        SetColor("ModernWarningText", dark ? "#FFD98A" : "#7A4A00");
        SetColor("ModernInfo", dark ? "#74B8F2" : "#4D9DE0");
        SetColor("ModernInfoContainer", dark ? "#1E3A5F" : "#D9EEFF");
        SetColor("ModernInfoText", dark ? "#B6DCFF" : "#1E5F96");

        SetColor("ModernTextPrimary", dark ? "#F8FAFC" : "#1A1A1A");
        SetColor("ModernTextSecondary", dark ? "#CBD5E1" : "#666666");
        SetColor("ModernTextHint", dark ? "#94A3B8" : "#999999");
        SetColor("ModernTextDisabled", dark ? "#64748B" : "#CCCCCC");
        SetColor("ModernTextInverse", "#FFFFFF");
    }

    private void SetColor(string key, string hex)
    {
        SetColor(Resources, key, Color.FromArgb(hex));
    }

    private static bool SetColor(ResourceDictionary resources, string key, Color color)
    {
        if (resources.ContainsKey(key))
        {
            resources[key] = color;
            return true;
        }

        foreach (var dictionary in resources.MergedDictionaries)
        {
            if (SetColor(dictionary, key, color))
                return true;
        }

        return false;
    }

    private AppTheme ResolveEffectiveTheme(AppTheme selectedTheme)
    {
        return selectedTheme == AppTheme.Unspecified ? RequestedTheme : selectedTheme;
    }

    private static AppTheme ToAppTheme(ThemePreference themePreference)
    {
        return themePreference switch
        {
            ThemePreference.Light => AppTheme.Light,
            ThemePreference.Dark => AppTheme.Dark,
            _ => AppTheme.Unspecified
        };
    }
}
