using MyItems.Enums;

namespace MyItems.Helpers;

public static class StatusHelper
{
    public static ExpiryStatus CalculateExpiryStatus(DateTime? expiryDate)
    {
        if (expiryDate is null)
            return ExpiryStatus.NoExpiry;

        var today = DateTime.Today;
        var threshold = today.AddDays(7);

        if (expiryDate.Value.Date < today)
            return ExpiryStatus.Expired;

        if (expiryDate.Value.Date <= threshold)
            return ExpiryStatus.Expiring;

        return ExpiryStatus.Safe;
    }

    public static WarrantyStatus CalculateWarrantyStatus(DateTime? warrantyDate)
    {
        if (warrantyDate is null)
            return WarrantyStatus.None;

        return warrantyDate.Value.Date < DateTime.Today
            ? WarrantyStatus.Expired
            : WarrantyStatus.Active;
    }

    public static string GetExpiryStatusText(ExpiryStatus status, DateTime? expiryDate)
    {
        return status switch
        {
            ExpiryStatus.Expired => $"过期 {(DateTime.Today - expiryDate!.Value.Date).Days} 天",
            ExpiryStatus.Expiring => $"还剩 {(expiryDate!.Value.Date - DateTime.Today).Days} 天",
            ExpiryStatus.Safe => "安全",
            ExpiryStatus.NoExpiry => "无保质期",
            _ => string.Empty
        };
    }

    public static string? GetWarrantyStatusText(WarrantyStatus status, DateTime? warrantyDate)
    {
        return status switch
        {
            WarrantyStatus.Active => $"保修至 {warrantyDate!.Value:yyyy-MM-dd}",
            WarrantyStatus.Expired => "已过保",
            _ => null
        };
    }

    public static string GetGroupTitle(ExpiryStatus status) => status switch
    {
        ExpiryStatus.Expired => "已过期",
        ExpiryStatus.Expiring => "临期",
        ExpiryStatus.Safe => "安全",
        ExpiryStatus.NoExpiry => "无保质期",
        _ => string.Empty
    };

    public static string GetGroupIcon(ExpiryStatus status) => status switch
    {
        ExpiryStatus.Expired => "\U0001F534",
        ExpiryStatus.Expiring => "\U0001F7E1",
        ExpiryStatus.Safe => "\U0001F7E2",
        ExpiryStatus.NoExpiry => "\U0001F535",
        _ => string.Empty
    };
}
