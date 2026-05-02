using SQLite;

namespace MyItems.Models;

[Table("Items")]
public class Item
{
    [PrimaryKey] public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    [Indexed] public Guid CategoryId { get; set; }
    public string? Barcode { get; set; }
    public string? Brand { get; set; }
    public string? Icon { get; set; }
    public string? DefaultLocation { get; set; }
    public bool IsArchived { get; set; }

    // 从 Batch 合并的字段
    public DateTime? PurchaseDate { get; set; }
    public decimal? PurchasePrice { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public int Quantity { get; set; } = 1;
    public bool TrackDailyCost { get; set; } = true;
    public string? Notes { get; set; }
    public string? ImagePath { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
}
