using MyItems.Enums;

namespace MyItems.Models.DTOs;

public class ItemDisplayDto
{
    public Guid ItemId { get; set; }
    public string ItemName { get; set; } = string.Empty;
    public string? ItemIcon { get; set; }
    public string? Brand { get; set; }
    public string? Barcode { get; set; }
    public Guid CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CategoryIcon { get; set; }
    public DateTime? PurchaseDate { get; set; }
    public decimal? PurchasePrice { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public string? Location { get; set; }
    public int Quantity { get; set; }
    public bool TrackDailyCost { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }

    // 显示用标识（替代原 BatchLabel）
    public string CreatedAtLabel => CreatedAt.ToString("yyyyMMddHHmmss");

    // 计算字段
    public ExpiryStatus ExpiryStatus { get; set; }
    public string ExpiryStatusText { get; set; } = string.Empty;
    public int HoldingDays { get; set; }
    public decimal DailyCost { get; set; }
    public string DailyCostText { get; set; } = string.Empty;
    public string HoldingText { get; set; } = string.Empty;

    public bool HasBrand => !string.IsNullOrWhiteSpace(Brand);
    public bool HasBarcode => !string.IsNullOrWhiteSpace(Barcode);
    public bool HasLocation => !string.IsNullOrWhiteSpace(Location);
    public bool HasNotes => !string.IsNullOrWhiteSpace(Notes);

    public string BrandDisplay => HasBrand ? Brand!.Trim() : "未填写";
    public string LocationDisplay => HasLocation ? Location!.Trim() : "未填写";
    public string PurchaseDateText => PurchaseDate?.ToString("yyyy-MM-dd") ?? "未记录";
    public string PurchasePriceText => PurchasePrice.HasValue ? $"¥{PurchasePrice.Value:F1}" : "未记录";
    public string ExpiryDateText => ExpiryDate?.ToString("yyyy-MM-dd") ?? "无保质期";
    public string DailyCostDisplay => string.IsNullOrWhiteSpace(DailyCostText) ? "未记录" : DailyCostText;
    public string NotesDisplay => HasNotes ? Notes!.Trim() : "暂无备注";
}
