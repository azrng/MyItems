namespace MyItems.Models.DTOs;

public class AddItemDto
{
    public string Name { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
    public string? Barcode { get; set; }
    public string? Brand { get; set; }
    public string? DefaultLocation { get; set; }
    public DateTime? PurchaseDate { get; set; }
    public decimal? PurchasePrice { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public bool NoExpiry { get; set; }
    public string? Location { get; set; }
    public int Quantity { get; set; } = 1;
    public string? Notes { get; set; }
}
