using System.Globalization;
using MyItems.Enums;

namespace MyItems.Converters;

public class ExpiryStatusToTextColorConverter : IValueConverter
{
    private static Color GetColor(string key, Color fallback)
    {
        return Application.Current?.Resources.TryGetValue(key, out var c) == true ? (Color)c : fallback;
    }

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is ExpiryStatus status)
        {
            return status switch
            {
                ExpiryStatus.Expired => GetColor("ModernErrorText", Color.FromArgb("#B42318")),
                ExpiryStatus.Expiring => GetColor("ModernWarningText", Colors.Orange),
                ExpiryStatus.Safe => GetColor("ModernSuccessText", Color.FromArgb("#146C52")),
                ExpiryStatus.NoExpiry => GetColor("ModernInfoText", Color.FromArgb("#1E5F96")),
                _ => Colors.Gray
            };
        }
        return Colors.Gray;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

public class ExpiryStatusToBgColorConverter : IValueConverter
{
    private static Color GetColor(string key, string fallback)
    {
        return Application.Current?.Resources.TryGetValue(key, out var c) == true ? (Color)c : Color.FromArgb(fallback);
    }

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is ExpiryStatus status)
        {
            return status switch
            {
                ExpiryStatus.Expired => GetColor("ModernErrorContainer", "#FFE4E8"),
                ExpiryStatus.Expiring => GetColor("ModernWarningContainer", "#FFF1B8"),
                ExpiryStatus.Safe => GetColor("ModernSuccessContainer", "#DCFBE6"),
                ExpiryStatus.NoExpiry => GetColor("ModernInfoContainer", "#D9EEFF"),
                _ => Colors.Transparent
            };
        }
        return Colors.Transparent;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

public class InvertedBoolConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is bool b ? !b : false;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is bool b ? !b : false;
}

public class StringNotNullOrEmptyConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is string s && !string.IsNullOrEmpty(s);

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

public class HasValueConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is not null && (value is not DateTime dt || dt != default);

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

public class BoolToColorConverter : IValueConverter
{
    private static Color GetColor(string key, Color fallback)
    {
        return Application.Current?.Resources.TryGetValue(key, out var c) == true ? (Color)c : fallback;
    }

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is bool isSelected && isSelected)
        {
            return GetColor("ModernPrimary", Colors.Pink);
        }
        return GetColor("ModernSurfaceContainer", Color.FromArgb("#F1F3F5"));
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
