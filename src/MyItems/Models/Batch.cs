using SQLite;

namespace MyItems.Models;

[Table("Batches")]
public class Batch
{
    [PrimaryKey] public Guid Id { get; set; } = Guid.NewGuid();
    [Indexed] public Guid ItemId { get; set; }
    public DateTime? PurchaseDate { get; set; }
    public decimal? PurchasePrice { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public string? Location { get; set; }
    public int Quantity { get; set; } = 1;
    public bool TrackDailyCost { get; set; } = true;
    public string? Notes { get; set; }
    public string? ImagePath { get; set; }
    public string BatchLabel { get; set; } = DateTime.Now.ToString("yyyy-MM-dd HH:mm");
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}
