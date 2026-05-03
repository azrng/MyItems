using SQLite;

namespace MyItems.Models;

[Table("VersionLog")]
public class VersionLog
{
    [PrimaryKey] public Guid Id { get; set; } = Guid.NewGuid();
    public int Version { get; set; }
    public string Description { get; set; } = string.Empty;
    public DateTime AppliedAt { get; set; } = DateTime.Now;
}
