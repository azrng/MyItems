using MyItems.Helpers;
using Xunit;

namespace MyItems.Tests.Helpers;

public sealed class ThemePreferenceHelperTests
{
    [Theory]
    [InlineData(0, ThemePreference.System)]
    [InlineData(1, ThemePreference.Light)]
    [InlineData(2, ThemePreference.Dark)]
    [InlineData(99, ThemePreference.System)]
    public void ToPreference_ReturnsExpectedThemePreference(int preference, ThemePreference expected)
    {
        var actual = ThemePreferenceHelper.ToPreference(preference);

        Assert.Equal(expected, actual);
    }
}
