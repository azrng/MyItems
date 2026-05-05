using CommunityToolkit.Mvvm.Input;
using MyItems.Models;

namespace MyItems.ViewModels;

public partial class SelectableCategory
{
    public Category Category { get; }

    public string Name => Category.Name;

    public bool IsSelected { get; set; }

    public Action<SelectableCategory>? OnSelect { get; set; }

    public IRelayCommand SelectCommand { get; }

    public SelectableCategory(Category category, bool isSelected = false)
    {
        Category = category;
        IsSelected = isSelected;
        SelectCommand = new RelayCommand(() =>
        {
            OnSelect?.Invoke(this);
        });
    }
}
