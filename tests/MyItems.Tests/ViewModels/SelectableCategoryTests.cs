using System.ComponentModel;
using MyItems.Models;
using MyItems.ViewModels;
using Xunit;

namespace MyItems.Tests.ViewModels;

public sealed class SelectableCategoryTests
{
    [Fact]
    public void IsSelected_RaisesPropertyChanged_WhenSelectionStateChanges()
    {
        var category = new SelectableCategory(new Category { Name = "食品" });
        var observable = Assert.IsAssignableFrom<INotifyPropertyChanged>(category);
        var changedProperties = new List<string?>();
        observable.PropertyChanged += (_, args) => changedProperties.Add(args.PropertyName);

        category.IsSelected = true;

        Assert.Contains(nameof(SelectableCategory.IsSelected), changedProperties);
    }
}
