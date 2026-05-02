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

    public static string GetExpiryStatusText(ExpiryStatus status, DateTime? expiryDate)
    {
        return status switch
        {
            ExpiryStatus.Expired when expiryDate.HasValue => $"过期 {(DateTime.Today - expiryDate.Value.Date).Days} 天",
            ExpiryStatus.Expired => "已过期",
            ExpiryStatus.Expiring when expiryDate.HasValue => $"临期 {(expiryDate.Value.Date - DateTime.Today).Days} 天",
            ExpiryStatus.Expiring => "临期",
            _ => string.Empty
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

    public static int GetHoldingDays(DateTime? purchaseDate)
    {
        if (purchaseDate is null)
            return 0;

        var days = (DateTime.Today - purchaseDate.Value.Date).Days;
        return days > 0 ? days : 1;
    }

    public static decimal CalculateDailyCost(decimal? price, int quantity, DateTime? purchaseDate)
    {
        if (price is null || purchaseDate is null)
            return 0;

        var days = GetHoldingDays(purchaseDate);
        if (days <= 0)
            return price.Value;

        return price.Value / days;
    }

    public static string GetHoldingText(DateTime? purchaseDate)
    {
        var days = GetHoldingDays(purchaseDate);
        if (days == 0)
            return "今天购入";
        return $"持有 {days} 天";
    }

    public static string GetDailyCostText(decimal? price, int quantity, DateTime? purchaseDate)
    {
        var dailyCost = CalculateDailyCost(price, quantity, purchaseDate);
        return $"¥{dailyCost:F2}/天";
    }
}
