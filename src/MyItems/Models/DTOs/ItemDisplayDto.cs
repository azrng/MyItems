using MyItems.Enums;

namespace MyItems.Models.DTOs;

public class ItemDisplayDto
{
    public Guid ItemId { get; set; }
    public string ItemName { get; set; } = string.Empty;
    public string? ItemIcon { get; set; }
    public string? Brand { get; set; }
    public Guid CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CategoryIcon { get; set; }
    public DateTime? PurchaseDate { get; set; }
    public decimal? PurchasePrice { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public string? Location { get; set; }
    public int Quantity { get; set; }
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
}
