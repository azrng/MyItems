using MyItems.Models;

namespace MyItems.Helpers;

public static class SearchFilterHelper
{
    private static SearchFilter? _currentFilter;

    public static SearchFilter? GetFilter()
    {
        var filter = _currentFilter;
        _currentFilter = null; // 取出后清空
        return filter;
    }

    public static void SetFilter(SearchFilter filter)
    {
        _currentFilter = filter;
    }
}
