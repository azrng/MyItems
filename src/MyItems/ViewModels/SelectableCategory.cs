using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;

namespace MyItems.ViewModels;

public partial class SelectableCategory : ObservableObject
{
    public Category Category { get; }

    public string Name => Category.Name;

    [ObservableProperty]
    public partial bool IsSelected { get; set; }

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
