using MyItems.Enums;

namespace MyItems.Models.DTOs;

public class ItemDisplayDto
{
    public Guid ItemId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Icon { get; set; }
    public Guid CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CategoryIcon { get; set; }
    public string? Barcode { get; set; }
    public string? Brand { get; set; }
    public string? DefaultLocation { get; set; }
    public int BatchCount { get; set; }
    public decimal TotalSpent { get; set; }
    public ExpiryStatus WorstExpiryStatus { get; set; }
    public string WorstExpiryStatusText { get; set; } = string.Empty;
    public string? DailyCostText { get; set; }
}
