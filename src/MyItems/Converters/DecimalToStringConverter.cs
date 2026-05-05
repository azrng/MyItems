using System.Globalization;

namespace MyItems.Converters;

public class DecimalToStringConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is null) return null;
        if (value is decimal d) return d.ToString("F2", CultureInfo.InvariantCulture);
        if (value is string s && decimal.TryParse(s, out var dec)) return dec.ToString("F2", CultureInfo.InvariantCulture);
        return value;
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is null) return null;
        if (value is string s && decimal.TryParse(s, out var dec)) return dec;
        return null;
    }
}
