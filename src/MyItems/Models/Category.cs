using SQLite;

namespace MyItems.Models;

[Table("Categories")]
public class Category
{
    [PrimaryKey] public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? Icon { get; set; }
    public int SortOrder { get; set; }
    public bool IsPreset { get; set; }
    public bool IsActive { get; set; } = true;
}
