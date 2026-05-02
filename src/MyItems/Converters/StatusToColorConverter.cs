using System.Globalization;
using MyItems.Enums;

namespace MyItems.Converters;

public class ExpiryStatusToTextColorConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is ExpiryStatus status)
        {
            return status switch
            {
                ExpiryStatus.Expired => Application.Current?.Resources.TryGetValue("AppExpiredColor", out var c) == true ? c : Colors.Red,
                ExpiryStatus.Expiring => Application.Current?.Resources.TryGetValue("AppExpiringColor", out var c) == true ? c : Colors.Orange,
                ExpiryStatus.Safe => Application.Current?.Resources.TryGetValue("AppSafeColor", out var c) == true ? c : Colors.Green,
                ExpiryStatus.NoExpiry => Application.Current?.Resources.TryGetValue("AppNoExpiryColor", out var c) == true ? c : Colors.Blue,
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
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is ExpiryStatus status)
        {
            return status switch
            {
                ExpiryStatus.Expired => Application.Current?.Resources.TryGetValue("AppExpiredBgColor", out var c) == true ? c : Color.FromArgb("#FFE0E4"),
                ExpiryStatus.Expiring => Application.Current?.Resources.TryGetValue("AppExpiringBgColor", out var c) == true ? c : Color.FromArgb("#FEEFC8"),
                ExpiryStatus.Safe => Application.Current?.Resources.TryGetValue("AppSafeBgColor", out var c) == true ? c : Color.FromArgb("#DCFBE6"),
                ExpiryStatus.NoExpiry => Application.Current?.Resources.TryGetValue("AppNoExpiryBgColor", out var c) == true ? c : Color.FromArgb("#D9EEFF"),
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
