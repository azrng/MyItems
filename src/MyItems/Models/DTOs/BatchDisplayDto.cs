using MyItems.Enums;

namespace MyItems.Models.DTOs;

public class BatchDisplayDto
{
    public Guid BatchId { get; set; }
    public Guid ItemId { get; set; }
    public string ItemName { get; set; } = string.Empty;
    public string? ItemIcon { get; set; }
    public string? Brand { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CategoryIcon { get; set; }
    public DateTime? PurchaseDate { get; set; }
    public decimal? PurchasePrice { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public string? Location { get; set; }
    public int Quantity { get; set; }
    public string? Notes { get; set; }
    public string BatchLabel { get; set; } = string.Empty;
    public bool TrackDailyCost { get; set; }
    public ExpiryStatus ExpiryStatus { get; set; }
    public string ExpiryStatusText { get; set; } = string.Empty;
    public int HoldingDays { get; set; }
    public decimal DailyCost { get; set; }
    public string DailyCostText { get; set; } = string.Empty;
    public string HoldingText { get; set; } = string.Empty;
}
