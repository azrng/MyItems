using CommunityToolkit.Mvvm.ComponentModel;

namespace MyItems.Models.DTOs;

public partial class CategoryDto : ObservableObject
{
    public Guid Id { get; set; }

    [ObservableProperty]
    public partial string Name { get; set; } = string.Empty;

    [ObservableProperty]
    public partial string? Icon { get; set; }

    public int SortOrder { get; set; }
    public bool IsPreset { get; set; }

    [ObservableProperty]
    public partial bool IsActive { get; set; } = true;

    public int ItemCount { get; set; }
    public string SubtitleText => IsPreset ? "预置" : $"{ItemCount} 个物品";
}
