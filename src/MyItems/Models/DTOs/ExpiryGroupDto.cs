using CommunityToolkit.Mvvm.ComponentModel;
using MyItems.Enums;

namespace MyItems.Models.DTOs;

public partial class ExpiryGroupDto : ObservableObject
{
    public ExpiryStatus Status { get; set; }
    public string Title { get; set; } = string.Empty;
    public string StatusIcon { get; set; } = string.Empty;
    public List<ItemDisplayDto> Items { get; set; } = [];
    public string HeaderText => $"{Title} ({Items.Count})";

    [ObservableProperty]
    private bool isExpanded;
}
