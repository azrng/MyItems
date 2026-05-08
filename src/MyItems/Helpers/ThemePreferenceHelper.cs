namespace MyItems.Helpers;

public static class ThemePreferenceHelper
{
    public const string PreferenceKey = "app_theme";

    public static ThemePreference ToPreference(int themePreference)
    {
        return themePreference switch
        {
            1 => ThemePreference.Light,
            2 => ThemePreference.Dark,
            _ => ThemePreference.System
        };
    }
}

public enum ThemePreference
{
    System = 0,
    Light = 1,
    Dark = 2
}
