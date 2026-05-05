using MyItems.Enums;

namespace MyItems.Converters;

public class ExpiryStatusVisibleConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, System.Globalization.CultureInfo culture)
    {
        if (value is ExpiryStatus status)
        {
            // 只在临期状态显示徽章，不在过期、安全或无保质期状态显示
            return status == ExpiryStatus.Expiring;
        }
        return false;
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, System.Globalization.CultureInfo culture)
    {
        throw new NotImplementedException();
    }
}
