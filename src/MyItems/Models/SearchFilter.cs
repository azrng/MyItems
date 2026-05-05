namespace MyItems.Models;

public class SearchFilter
{
    public string? Keyword { get; set; }
    public decimal? MinPrice { get; set; }
    public decimal? MaxPrice { get; set; }
    public DateTime? PurchaseDateFrom { get; set; }
    public DateTime? PurchaseDateTo { get; set; }
    public DateTime? ExpiryDateFrom { get; set; }
    public DateTime? ExpiryDateTo { get; set; }
    public Guid? CategoryId { get; set; }
    public bool HasExpiry { get; set; }
    public bool OnlyExpiring { get; set; }  // 只显示临期/已过期
    public bool OnlyExpired { get; set; }   // 只显示已过期

    public bool IsActive =>
        !string.IsNullOrWhiteSpace(Keyword) ||
        MinPrice.HasValue || MaxPrice.HasValue ||
        PurchaseDateFrom.HasValue || PurchaseDateTo.HasValue ||
        ExpiryDateFrom.HasValue || ExpiryDateTo.HasValue ||
        CategoryId.HasValue ||
        HasExpiry || OnlyExpiring || OnlyExpired;

    public void Clear()
    {
        Keyword = null;
        MinPrice = null;
        MaxPrice = null;
        PurchaseDateFrom = null;
        PurchaseDateTo = null;
        ExpiryDateFrom = null;
        ExpiryDateTo = null;
        CategoryId = null;
        HasExpiry = false;
        OnlyExpiring = false;
        OnlyExpired = false;
    }

    public object Clone()
    {
        return new SearchFilter
        {
            Keyword = Keyword,
            MinPrice = MinPrice,
            MaxPrice = MaxPrice,
            PurchaseDateFrom = PurchaseDateFrom,
            PurchaseDateTo = PurchaseDateTo,
            ExpiryDateFrom = ExpiryDateFrom,
            ExpiryDateTo = ExpiryDateTo,
            CategoryId = CategoryId,
            HasExpiry = HasExpiry,
            OnlyExpiring = OnlyExpiring,
            OnlyExpired = OnlyExpired
        };
    }
}
