using System.Globalization;
using MyItems.Enums;

namespace MyItems.Converters;

public class ExpiryStatusToTextColorConverter : IValueConverter
{
    private static Color? _expired, _expiring, _safe, _noExpiry;

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
                ExpiryStatus.Expired => _expired ??= GetColor("AppExpiredColor", Colors.Red),
                ExpiryStatus.Expiring => _expiring ??= GetColor("AppExpiringColor", Colors.Orange),
                ExpiryStatus.Safe => _safe ??= GetColor("AppSafeColor", Colors.Green),
                ExpiryStatus.NoExpiry => _noExpiry ??= GetColor("AppNoExpiryColor", Colors.Blue),
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
    private static Color? _expired, _expiring, _safe, _noExpiry;

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
                ExpiryStatus.Expired => _expired ??= GetColor("AppExpiredBgColor", "#FFE0E4"),
                ExpiryStatus.Expiring => _expiring ??= GetColor("AppExpiringBgColor", "#FEEFC8"),
                ExpiryStatus.Safe => _safe ??= GetColor("AppSafeBgColor", "#DCFBE6"),
                ExpiryStatus.NoExpiry => _noExpiry ??= GetColor("AppNoExpiryBgColor", "#D9EEFF"),
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
